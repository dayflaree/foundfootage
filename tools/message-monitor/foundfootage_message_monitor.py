#!/usr/bin/env python3
"""Native Linux monitor for the Found Footage global message service."""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import json
import os
from pathlib import Path
import threading
import urllib.error
import urllib.parse
import urllib.request
import webbrowser

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("Pango", "1.0")
from gi.repository import Gdk, Gio, GLib, Gtk, Pango  # noqa: E402

APP_ID = "io.foundfootage.MessageMonitor"
APP_NAME = "Found Footage Message Monitor"
DEFAULT_API_URL = "https://foundfootage-messages.foundfootage-elijah.workers.dev"
DEFAULT_TOKEN_FILE = Path(__file__).resolve().parents[2] / "services" / "message-service" / ".admin-token"
REFRESH_SECONDS = 10


class FeedError(RuntimeError):
    """Raised when the remote admin feed cannot be read."""


@dataclasses.dataclass(slots=True)
class Message:
    sequence: int
    message_id: str
    map_name: str
    author_steamid64: str
    body: str
    position: tuple[float, float, float]
    normal: tuple[float, float, float]
    created_at: int
    deleted_at: int | None
    report_count: int
    event_id: int

    @classmethod
    def from_event(cls, event: dict[str, object]) -> "Message":
        raw = event.get("message")
        if not isinstance(raw, dict):
            raise FeedError("Admin feed returned an event without a message object.")

        position = raw.get("position")
        normal = raw.get("normal")
        if not isinstance(position, dict) or not isinstance(normal, dict):
            raise FeedError("Admin feed returned invalid world coordinates.")

        def vector(source: dict[str, object]) -> tuple[float, float, float]:
            return (
                float(source.get("x", 0.0)),
                float(source.get("y", 0.0)),
                float(source.get("z", 0.0)),
            )

        deleted = raw.get("deleted_at")
        return cls(
            sequence=int(raw.get("sequence", 0)),
            message_id=str(raw.get("id", "")),
            map_name=str(raw.get("map_name", "")),
            author_steamid64=str(raw.get("author_steamid64", "")),
            body=str(raw.get("body", "")),
            position=vector(position),
            normal=vector(normal),
            created_at=int(raw.get("created_at", 0)),
            deleted_at=int(deleted) if deleted is not None else None,
            report_count=int(raw.get("report_count", 0)),
            event_id=int(event.get("event_id", 0)),
        )

    @property
    def status(self) -> str:
        return "DELETED" if self.deleted_at is not None else "ACTIVE"

    @property
    def created_display(self) -> str:
        return format_timestamp(self.created_at)

    @property
    def deleted_display(self) -> str:
        return format_timestamp(self.deleted_at) if self.deleted_at is not None else "—"

    @property
    def position_display(self) -> str:
        return format_vector(self.position)

    @property
    def normal_display(self) -> str:
        return format_vector(self.normal)


class AdminFeedClient:
    def __init__(self, api_url: str, token_file: Path) -> None:
        self.api_url = api_url.rstrip("/")
        self.token_file = token_file

    def _token(self) -> str:
        try:
            token = self.token_file.read_text(encoding="utf-8").strip()
        except FileNotFoundError as error:
            raise FeedError(f"Admin token file is missing: {self.token_file}") from error
        except OSError as error:
            raise FeedError(f"Admin token could not be read: {error}") from error
        if not token:
            raise FeedError(f"Admin token file is empty: {self.token_file}")
        return token

    def _json(self, path: str, *, admin: bool = False, method: str = "GET") -> dict[str, object]:
        headers = {
            "Accept": "application/json",
            "User-Agent": "FoundFootage-MessageMonitor/1.0",
        }
        if admin:
            headers["X-Admin-Token"] = self._token()

        request = urllib.request.Request(self.api_url + path, headers=headers, method=method.upper())
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            detail = ""
            try:
                decoded = json.loads(error.read().decode("utf-8"))
                detail = str(decoded.get("message", ""))
            except Exception:
                pass
            suffix = f": {detail}" if detail else ""
            raise FeedError(f"Server returned HTTP {error.code}{suffix}") from error
        except urllib.error.URLError as error:
            raise FeedError(f"Could not reach the Cloudflare service: {error.reason}") from error
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise FeedError("Cloudflare returned an unreadable response.") from error

        if not isinstance(payload, dict) or payload.get("ok") is not True:
            raise FeedError("Cloudflare returned an unsuccessful response.")
        return payload

    def health(self) -> dict[str, object]:
        return self._json("/health")

    def fetch_events(self, after: int) -> tuple[list[dict[str, object]], int]:
        events: list[dict[str, object]] = []
        cursor = max(0, int(after))

        while True:
            query = urllib.parse.urlencode({"after": cursor, "limit": 500})
            payload = self._json(f"/v1/admin/feed?{query}", admin=True)
            page = payload.get("events", [])
            if not isinstance(page, list):
                raise FeedError("Admin feed returned an invalid event list.")
            events.extend(event for event in page if isinstance(event, dict))

            next_cursor = int(payload.get("cursor", cursor))
            has_more = payload.get("has_more") is True
            if not has_more or next_cursor <= cursor:
                cursor = max(cursor, next_cursor)
                break
            cursor = next_cursor

        return events, cursor

    def permanently_delete_message(self, message_id: str) -> None:
        safe_id = urllib.parse.quote(message_id, safe="")
        payload = self._json(
            f"/v1/admin/messages/{safe_id}/permanent",
            admin=True,
            method="DELETE",
        )
        if payload.get("permanently_deleted") is not True:
            raise FeedError("Cloudflare did not confirm permanent deletion.")


def format_timestamp(timestamp: int | None) -> str:
    if timestamp is None or timestamp <= 0:
        return "—"
    return dt.datetime.fromtimestamp(timestamp).astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")


def format_vector(value: tuple[float, float, float]) -> str:
    return f"{value[0]:.2f}, {value[1]:.2f}, {value[2]:.2f}"


class MonitorWindow(Gtk.ApplicationWindow):
    COL_SEQUENCE = 0
    COL_CREATED_TS = 1
    COL_CREATED = 2
    COL_MAP = 3
    COL_AUTHOR = 4
    COL_BODY = 5
    COL_STATUS = 6
    COL_REPORTS = 7
    COL_ID = 8
    COL_POSITION = 9
    COL_NORMAL = 10
    COL_DELETED = 11

    def __init__(self, application: Gtk.Application, client: AdminFeedClient) -> None:
        super().__init__(application=application, title=APP_NAME)
        self.client = client
        self.messages: dict[str, Message] = {}
        self.row_references: dict[str, Gtk.TreeRowReference] = {}
        self.cursor = 0
        self.fetching = False
        self.initialized = False
        self.selected_message_id: str | None = None
        self.deleting_message_id: str | None = None

        self.set_default_size(1320, 780)
        self.set_size_request(900, 560)
        self.set_icon_name("foundfootage-message-monitor")
        self.get_style_context().add_class("monitor-window")

        self._build_ui()
        self._install_css()
        self.show_all()
        self.refresh(full=True)
        GLib.timeout_add_seconds(REFRESH_SECONDS, self._poll)

    def _build_ui(self) -> None:
        header = Gtk.HeaderBar()
        header.set_show_close_button(True)
        header.props.title = "FOUND FOOTAGE"
        header.props.subtitle = "GLOBAL MESSAGE MONITOR"
        self.set_titlebar(header)

        self.refresh_button = Gtk.Button.new_from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON)
        self.refresh_button.set_tooltip_text("Refresh the global message feed")
        self.refresh_button.connect("clicked", lambda _button: self.refresh(full=False))
        header.pack_start(self.refresh_button)

        self.live_switch = Gtk.Switch()
        self.live_switch.set_active(True)
        self.live_switch.set_tooltip_text(f"Poll every {REFRESH_SECONDS} seconds")
        live_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        live_label = Gtk.Label(label="LIVE")
        live_label.get_style_context().add_class("live-label")
        live_box.pack_start(live_label, False, False, 0)
        live_box.pack_start(self.live_switch, False, False, 0)
        header.pack_end(live_box)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(root)

        filters = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        filters.set_border_width(12)
        root.pack_start(filters, False, False, 0)

        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_placeholder_text("Search message, map, SteamID64, or UUID")
        self.search_entry.set_hexpand(True)
        self.search_entry.connect("search-changed", lambda _entry: self.filter_model.refilter())
        filters.pack_start(self.search_entry, True, True, 0)

        self.map_combo = Gtk.ComboBoxText()
        self.map_combo.append_text("All maps")
        self.map_combo.set_active(0)
        self.map_combo.set_size_request(210, -1)
        self.map_combo.connect("changed", lambda _combo: self.filter_model.refilter())
        filters.pack_start(self.map_combo, False, False, 0)

        self.show_deleted = Gtk.CheckButton(label="Show deleted")
        self.show_deleted.set_active(True)
        self.show_deleted.connect("toggled", lambda _button: self.filter_model.refilter())
        filters.pack_start(self.show_deleted, False, False, 0)

        paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        paned.set_position(880)
        root.pack_start(paned, True, True, 0)

        self.store = Gtk.ListStore(
            int, int, str, str, str, str, str, int, str, str, str, str
        )
        self.filter_model = self.store.filter_new()
        self.filter_model.set_visible_func(self._row_visible)
        self.sort_model = Gtk.TreeModelSort(model=self.filter_model)
        self.sort_model.set_sort_column_id(self.COL_CREATED_TS, Gtk.SortType.DESCENDING)

        self.tree = Gtk.TreeView(model=self.sort_model)
        self.tree.set_headers_visible(True)
        self.tree.set_enable_search(False)
        self.tree.get_selection().connect("changed", self._selection_changed)
        self.tree.connect("row-activated", self._row_activated)

        self._add_text_column("TIME", self.COL_CREATED, 172)
        self._add_text_column("MAP", self.COL_MAP, 150)
        self._add_text_column("AUTHOR / STEAMID64", self.COL_AUTHOR, 170)
        self._add_text_column("MESSAGE", self.COL_BODY, 360, expand=True)
        self._add_status_column()
        self._add_text_column("REPORTS", self.COL_REPORTS, 70)

        list_scroll = Gtk.ScrolledWindow()
        list_scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        list_scroll.add(self.tree)
        paned.pack1(list_scroll, resize=True, shrink=False)

        details = self._build_details_panel()
        paned.pack2(details, resize=False, shrink=False)

        status_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        status_box.set_border_width(8)
        root.pack_end(status_box, False, False, 0)

        self.status_dot = Gtk.Label(label="●")
        self.status_dot.get_style_context().add_class("status-dot")
        status_box.pack_start(self.status_dot, False, False, 0)

        self.status_label = Gtk.Label(label="Connecting to Cloudflare…")
        self.status_label.set_xalign(0)
        self.status_label.set_ellipsize(Pango.EllipsizeMode.END)
        status_box.pack_start(self.status_label, True, True, 0)

        self.count_label = Gtk.Label(label="0 messages")
        status_box.pack_end(self.count_label, False, False, 0)

    def _build_details_panel(self) -> Gtk.Widget:
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        outer.set_border_width(16)
        outer.set_size_request(360, -1)

        title = Gtk.Label()
        title.set_markup("<b>MESSAGE DETAILS</b>")
        title.set_xalign(0)
        outer.pack_start(title, False, False, 0)

        self.detail_body = Gtk.TextView()
        self.detail_body.set_editable(False)
        self.detail_body.set_cursor_visible(False)
        self.detail_body.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.detail_body.set_size_request(-1, 150)
        self.detail_body.get_style_context().add_class("detail-message")
        body_scroll = Gtk.ScrolledWindow()
        body_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        body_scroll.add(self.detail_body)
        outer.pack_start(body_scroll, False, True, 0)

        grid = Gtk.Grid(column_spacing=10, row_spacing=8)
        outer.pack_start(grid, False, False, 0)
        self.detail_labels: dict[str, Gtk.Label] = {}
        rows = [
            ("status", "Status"),
            ("map", "Map"),
            ("author", "SteamID64"),
            ("created", "Created"),
            ("deleted", "Deleted"),
            ("position", "Position"),
            ("normal", "Normal"),
            ("reports", "Reports"),
            ("id", "Message ID"),
        ]
        for row, (key, caption) in enumerate(rows):
            caption_label = Gtk.Label(label=caption)
            caption_label.set_xalign(0)
            caption_label.get_style_context().add_class("detail-caption")
            grid.attach(caption_label, 0, row, 1, 1)

            value = Gtk.Label(label="—")
            value.set_xalign(0)
            value.set_selectable(True)
            value.set_line_wrap(True)
            value.set_hexpand(True)
            grid.attach(value, 1, row, 1, 1)
            self.detail_labels[key] = value

        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        outer.pack_start(button_box, False, False, 0)

        self.profile_button = Gtk.Button(label="Open Steam Profile")
        self.profile_button.set_sensitive(False)
        self.profile_button.connect("clicked", self._open_profile)
        button_box.pack_start(self.profile_button, True, True, 0)

        self.copy_button = Gtk.Button(label="Copy ID")
        self.copy_button.set_sensitive(False)
        self.copy_button.connect("clicked", self._copy_id)
        button_box.pack_start(self.copy_button, False, False, 0)

        self.delete_button = Gtk.Button(label="Delete Permanently")
        self.delete_button.set_sensitive(False)
        self.delete_button.set_tooltip_text("Irreversibly remove this message from Cloudflare D1")
        self.delete_button.get_style_context().add_class("destructive-action")
        self.delete_button.connect("clicked", self._confirm_permanent_delete)
        outer.pack_start(self.delete_button, False, False, 0)

        hint = Gtk.Label(label="Double-click a row to open its Steam profile.")
        hint.set_xalign(0)
        hint.set_line_wrap(True)
        hint.get_style_context().add_class("detail-hint")
        outer.pack_end(hint, False, False, 0)

        return outer

    def _add_text_column(self, title: str, column: int, width: int, *, expand: bool = False) -> None:
        renderer = Gtk.CellRendererText()
        renderer.set_property("ellipsize", Pango.EllipsizeMode.END)
        if column == self.COL_BODY:
            renderer.set_property("wrap-mode", Pango.WrapMode.WORD_CHAR)
            renderer.set_property("wrap-width", width)
        tree_column = Gtk.TreeViewColumn(title, renderer, text=column)
        tree_column.set_resizable(True)
        tree_column.set_min_width(width)
        tree_column.set_expand(expand)
        tree_column.set_sort_column_id(column)
        self.tree.append_column(tree_column)

    def _add_status_column(self) -> None:
        renderer = Gtk.CellRendererText()
        renderer.set_property("weight", Pango.Weight.BOLD)
        column = Gtk.TreeViewColumn("STATUS", renderer, text=self.COL_STATUS)
        column.set_min_width(84)
        column.set_cell_data_func(renderer, self._status_cell_style)
        self.tree.append_column(column)

    @staticmethod
    def _status_cell_style(_column: Gtk.TreeViewColumn, renderer: Gtk.CellRendererText,
                           model: Gtk.TreeModel, tree_iter: Gtk.TreeIter, _data: object) -> None:
        status = model.get_value(tree_iter, MonitorWindow.COL_STATUS)
        renderer.set_property("foreground", "#ef6f67" if status == "DELETED" else "#76d99a")

    def _install_css(self) -> None:
        css = b"""
        .monitor-window { background: #101411; }
        headerbar { background: #182019; color: #ecf2e9; }
        treeview { background: #0d110e; color: #e6ece3; }
        treeview:selected { background: #355642; color: #ffffff; }
        .detail-message { background: #080b09; color: #f1f5ef; font: 15px monospace; }
        .detail-caption { color: #8ba092; font-weight: bold; }
        .detail-hint { color: #718077; font-size: 11px; }
        .live-label { color: #8ed6a2; font-weight: bold; }
        .status-dot { color: #76d99a; }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        screen = Gdk.Screen.get_default()
        if screen is not None:
            Gtk.StyleContext.add_provider_for_screen(
                screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def _row_visible(self, model: Gtk.TreeModel, tree_iter: Gtk.TreeIter, _data: object) -> bool:
        if not self.show_deleted.get_active() and model.get_value(tree_iter, self.COL_STATUS) == "DELETED":
            return False

        selected_map = self.map_combo.get_active_text()
        if selected_map and selected_map != "All maps":
            if model.get_value(tree_iter, self.COL_MAP) != selected_map:
                return False

        query = self.search_entry.get_text().strip().casefold()
        if not query:
            return True
        haystack = " ".join(
            str(model.get_value(tree_iter, column))
            for column in (self.COL_MAP, self.COL_AUTHOR, self.COL_BODY, self.COL_ID)
        ).casefold()
        return query in haystack

    def _selection_changed(self, selection: Gtk.TreeSelection) -> None:
        model, tree_iter = selection.get_selected()
        if tree_iter is None:
            self._show_details(None)
            return
        message_id = model.get_value(tree_iter, self.COL_ID)
        self._show_details(self.messages.get(message_id))

    def _row_activated(self, model: Gtk.TreeView, path: Gtk.TreePath, _column: Gtk.TreeViewColumn) -> None:
        tree_iter = model.get_model().get_iter(path)
        message_id = model.get_model().get_value(tree_iter, self.COL_ID)
        message = self.messages.get(message_id)
        if message:
            webbrowser.open(f"https://steamcommunity.com/profiles/{message.author_steamid64}")

    def _show_details(self, message: Message | None) -> None:
        self.selected_message_id = message.message_id if message else None
        buffer = self.detail_body.get_buffer()
        buffer.set_text(message.body if message else "Select a message from the live feed.")

        values = {
            "status": message.status if message else "—",
            "map": message.map_name if message else "—",
            "author": message.author_steamid64 if message else "—",
            "created": message.created_display if message else "—",
            "deleted": message.deleted_display if message else "—",
            "position": message.position_display if message else "—",
            "normal": message.normal_display if message else "—",
            "reports": str(message.report_count) if message else "—",
            "id": message.message_id if message else "—",
        }
        for key, value in values.items():
            self.detail_labels[key].set_text(value)

        enabled = message is not None
        self.profile_button.set_sensitive(enabled)
        self.copy_button.set_sensitive(enabled)
        self.delete_button.set_sensitive(enabled and self.deleting_message_id is None)

    def _open_profile(self, _button: Gtk.Button) -> None:
        message = self.messages.get(self.selected_message_id or "")
        if message:
            webbrowser.open(f"https://steamcommunity.com/profiles/{message.author_steamid64}")

    def _copy_id(self, _button: Gtk.Button) -> None:
        message = self.messages.get(self.selected_message_id or "")
        if not message:
            return
        clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        clipboard.set_text(message.message_id, -1)
        self._set_status("Message UUID copied to clipboard.", healthy=True)

    def _confirm_permanent_delete(self, _button: Gtk.Button) -> None:
        message = self.messages.get(self.selected_message_id or "")
        if not message or self.deleting_message_id is not None:
            return

        dialog = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            destroy_with_parent=True,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.NONE,
            text="Delete this message permanently?",
        )
        dialog.format_secondary_text(
            "This permanently removes the message text, author record, coordinates, reports, "
            "and prior history from Cloudflare D1. A content-free deletion signal remains so "
            "active game servers remove the tape. This action cannot be undone.\n\n"
            f"Map: {message.map_name}\n"
            f"Author: {message.author_steamid64}\n"
            f"Message: {message.body[:180]}"
        )
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        delete_action = dialog.add_button("Delete Permanently", Gtk.ResponseType.ACCEPT)
        delete_action.get_style_context().add_class("destructive-action")
        dialog.set_default_response(Gtk.ResponseType.CANCEL)

        response = dialog.run()
        dialog.destroy()
        if response != Gtk.ResponseType.ACCEPT:
            return

        self.deleting_message_id = message.message_id
        self.delete_button.set_sensitive(False)
        self.refresh_button.set_sensitive(False)
        self._set_status(
            f"Permanently deleting {message.message_id} from Cloudflare…",
            healthy=True,
        )
        thread = threading.Thread(
            target=self._permanent_delete_worker,
            args=(message.message_id,),
            daemon=True,
        )
        thread.start()

    def _permanent_delete_worker(self, message_id: str) -> None:
        try:
            self.client.permanently_delete_message(message_id)
        except Exception as error:
            GLib.idle_add(self._permanent_delete_failed, message_id, str(error))
            return
        GLib.idle_add(self._permanent_delete_succeeded, message_id)

    def _permanent_delete_failed(self, message_id: str, reason: str) -> bool:
        if self.deleting_message_id == message_id:
            self.deleting_message_id = None
        self.refresh_button.set_sensitive(True)
        self.delete_button.set_sensitive(self.selected_message_id is not None)
        self._set_status(f"Permanent deletion failed: {reason}", healthy=False)
        return False

    def _permanent_delete_succeeded(self, message_id: str) -> bool:
        reference = self.row_references.pop(message_id, None)
        if reference is not None:
            path = reference.get_path()
            if path is not None:
                tree_iter = self.store.get_iter(path)
                if tree_iter is not None:
                    self.store.remove(tree_iter)

        self.messages.pop(message_id, None)
        self.deleting_message_id = None
        self.refresh_button.set_sensitive(True)
        if self.selected_message_id == message_id:
            self.tree.get_selection().unselect_all()
            self._show_details(None)

        self._rebuild_map_filter()
        self.filter_model.refilter()
        self._update_counts()
        self._set_status("Message permanently deleted from Cloudflare D1.", healthy=True)
        return False

    def _poll(self) -> bool:
        if self.live_switch.get_active():
            self.refresh(full=False)
        return True

    def refresh(self, *, full: bool) -> None:
        if self.fetching:
            return
        self.fetching = True
        self.refresh_button.set_sensitive(False)
        self._set_status("Reading the global Cloudflare feed…", healthy=True)

        thread = threading.Thread(target=self._fetch_worker, args=(full,), daemon=True)
        thread.start()

    def _fetch_worker(self, full: bool) -> None:
        try:
            after = 0 if full else self.cursor
            events, cursor = self.client.fetch_events(after)
        except Exception as error:
            GLib.idle_add(self._fetch_failed, str(error))
            return
        GLib.idle_add(self._apply_events, events, cursor, full)

    def _fetch_failed(self, message: str) -> bool:
        self.fetching = False
        self.refresh_button.set_sensitive(True)
        self._set_status(message, healthy=False)
        return False

    def _apply_events(self, events: list[dict[str, object]], cursor: int, full: bool) -> bool:
        new_creations: list[Message] = []
        if full:
            self.messages.clear()
            self.row_references.clear()
            self.store.clear()
            self.cursor = 0

        for event in events:
            try:
                message = Message.from_event(event)
            except (FeedError, TypeError, ValueError):
                continue
            if not message.message_id:
                continue
            is_new = message.message_id not in self.messages
            self.messages[message.message_id] = message
            self._upsert_row(message)
            if is_new and event.get("type") == "create":
                new_creations.append(message)

        self.cursor = max(self.cursor, cursor)
        self.fetching = False
        self.refresh_button.set_sensitive(True)
        self.initialized = True
        self._rebuild_map_filter()
        self.filter_model.refilter()
        self._update_counts()
        self._set_status(
            f"Live • Last update {dt.datetime.now().astimezone().strftime('%H:%M:%S %Z')} • Cursor {self.cursor}",
            healthy=True,
        )

        if not full and new_creations:
            newest = max(new_creations, key=lambda item: item.created_at)
            notification = Gio.Notification.new("New Found Footage message")
            notification.set_body(f"{newest.map_name} • {newest.author_steamid64}\n{newest.body[:120]}")
            application = self.get_application()
            if application:
                application.send_notification("new-message", notification)

        if self.selected_message_id:
            self._show_details(self.messages.get(self.selected_message_id))
        return False

    def _upsert_row(self, message: Message) -> None:
        values = [
            message.sequence,
            message.created_at,
            message.created_display,
            message.map_name,
            message.author_steamid64,
            message.body.replace("\n", "  "),
            message.status,
            message.report_count,
            message.message_id,
            message.position_display,
            message.normal_display,
            message.deleted_display,
        ]

        reference = self.row_references.get(message.message_id)
        tree_iter: Gtk.TreeIter | None = None
        if reference is not None:
            path = reference.get_path()
            if path is not None:
                tree_iter = self.store.get_iter(path)

        if tree_iter is None:
            tree_iter = self.store.append(values)
            path = self.store.get_path(tree_iter)
            self.row_references[message.message_id] = Gtk.TreeRowReference.new(self.store, path)
        else:
            for column, value in enumerate(values):
                self.store.set_value(tree_iter, column, value)

    def _rebuild_map_filter(self) -> None:
        current = self.map_combo.get_active_text() or "All maps"
        maps = sorted({message.map_name for message in self.messages.values() if message.map_name})
        self.map_combo.remove_all()
        self.map_combo.append_text("All maps")
        active = 0
        for index, map_name in enumerate(maps, start=1):
            self.map_combo.append_text(map_name)
            if map_name == current:
                active = index
        self.map_combo.set_active(active)

    def _update_counts(self) -> None:
        active = sum(1 for message in self.messages.values() if message.deleted_at is None)
        deleted = len(self.messages) - active
        self.count_label.set_text(
            f"{len(self.messages)} total • {active} active • {deleted} deleted"
        )

    def _set_status(self, text: str, *, healthy: bool) -> None:
        self.status_label.set_text(text)
        self.status_dot.get_style_context().remove_class("status-error")
        self.status_dot.get_style_context().remove_class("status-ok")
        self.status_dot.get_style_context().add_class("status-ok" if healthy else "status-error")
        self.status_dot.set_markup(
            '<span foreground="#76d99a">●</span>' if healthy
            else '<span foreground="#ef6f67">●</span>'
        )


class MonitorApplication(Gtk.Application):
    def __init__(self, client: AdminFeedClient) -> None:
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.client = client
        self.window: MonitorWindow | None = None

    def do_activate(self) -> None:
        if self.window is None:
            self.window = MonitorWindow(self, self.client)
        self.window.present()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=APP_NAME)
    parser.add_argument(
        "--api-url",
        default=os.environ.get("FOUNDFOOTAGE_MESSAGE_API", DEFAULT_API_URL),
        help="Cloudflare Worker base URL",
    )
    parser.add_argument(
        "--token-file",
        type=Path,
        default=Path(os.environ.get("FOUNDFOOTAGE_ADMIN_TOKEN_FILE", str(DEFAULT_TOKEN_FILE))),
        help="Path containing the Cloudflare administrator token",
    )
    parser.add_argument("--self-test", action="store_true", help="Check health and admin feed, then exit")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    client = AdminFeedClient(args.api_url, args.token_file)

    if args.self_test:
        health = client.health()
        events, cursor = client.fetch_events(0)
        unique_messages = {
            str(event.get("message", {}).get("id", ""))
            for event in events
            if isinstance(event.get("message"), dict)
        }
        unique_messages.discard("")
        print(json.dumps({
            "health": health,
            "events": len(events),
            "messages": len(unique_messages),
            "cursor": cursor,
        }, indent=2))
        return 0

    application = MonitorApplication(client)
    return int(application.run(None))


if __name__ == "__main__":
    raise SystemExit(main())
