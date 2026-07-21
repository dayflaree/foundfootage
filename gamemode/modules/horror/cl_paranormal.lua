local config = FF_CONFIG.Horror.Paranormal
if not config.Enabled then return end

net.Receive("FF_ParanormalInterference", function()
    local duration = math.Clamp(net.ReadFloat(), 0.1, 2)
    if not FF_CONFIG.Flashlight.Enabled then return end

    if FF_PushCamcorderSignal then
        FF_PushCamcorderSignal(1, duration + 0.35, "paranormal_interference")
    end

    if FF_PushRecordingFault then
        FF_PushRecordingFault("SIGNAL LOSS", duration + 0.45, 1, 100)
    end

    if FF_SetTemporaryClientConVarOverride then
        FF_SetTemporaryClientConVarOverride("cflash_enabled", "0", duration)
    end
end)
