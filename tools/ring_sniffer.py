#!/usr/bin/env python3
"""
ring_sniffer.py — BLE packet sniffer for Smart Ring gesture discovery.
Scans, finds the ring, and immediately connects without losing it from cache.

Usage:
    python3 ring_sniffer.py

Requirements:
    pip3 install bleak
"""

import asyncio
import os
import sys
from datetime import datetime
from bleak import BleakScanner, BleakClient
from bleak.backends.characteristic import BleakGATTCharacteristic
from bleak.backends.device import BLEDevice
from bleak.backends.scanner import AdvertisementData

RING_KEYWORDS = ["SSR", "RING", "R0", "COLMI"]
DEFAULT_MAC   = "B0:24:08:02:06:87"

LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ring_log.txt")
_logfile = open(LOG_FILE, "w", buffering=1)

KNOWN = {
    0x03: "BATTERY",
    0xA1: "ACCEL/SENSOR",
    0x14: "GESTURE/TAP",
    0x51: "ACTIVITY",
    0x52: "ACTIVITY-2",
    0x08: "HEART RATE",
    0x22: "SPO2",
    0x69: "SLEEP",
    0x01: "DEVICE INFO",
}

accel_count = 0

def ts():
    return datetime.now().strftime("%H:%M:%S.%f")[:-3]

def log(msg=""):
    line = str(msg)
    print(line)
    sys.stdout.flush()
    _logfile.write(line + "\n")
    _logfile.flush()

def on_notify(char: BleakGATTCharacteristic, data: bytearray):
    global accel_count
    if not data:
        return
    b0 = data[0]
    b1 = data[1] if len(data) > 1 else 0
    hexstr = " ".join(f"{x:02X}" for x in data)
    label = KNOWN.get(b0, f"UNKNOWN_0x{b0:02X}")

    # Accelerometer — очень частые, показываем каждый 60-й
    if b0 == 0xA1 and b1 == 0x03:
        accel_count += 1
        if accel_count % 60 == 1:
            log(f"[{ts()}] 📡 ACCEL #{accel_count:>5}  {hexstr[:32]}...")
        return

    # Все остальные пакеты — выводим всегда
    if b0 == 0x14:
        log(f"[{ts()}] 👆❗ {label:<18} len={len(data):>2}  HEX: {hexstr}")
        log(f"         ↳ subtype=0x{b1:02X}  raw={list(data)}")
    elif b0 == 0x03:
        log(f"[{ts()}] 🔋  {label:<18} len={len(data):>2}  HEX: {hexstr}")
    elif b0 == 0xA1:
        log(f"[{ts()}] 📦  {label} sub=0x{b1:02X}  len={len(data):>2}  HEX: {hexstr}")
    elif b0 in KNOWN:
        log(f"[{ts()}] ℹ️   {label:<18} len={len(data):>2}  HEX: {hexstr}")
    else:
        log(f"[{ts()}] ❓  {label:<18} len={len(data):>2}  HEX: {hexstr}  ← NEW!")

async def run():
    found_device: BLEDevice | None = None

    log("🔍 Scanning (держи кольцо рядом с Mac)...")
    
    stop_event = asyncio.Event()

    def detection_callback(device: BLEDevice, adv: AdvertisementData):
        nonlocal found_device
        if found_device:
            return
        name = (device.name or adv.local_name or "").upper()
        is_ring = any(k in name for k in RING_KEYWORDS)
        log(f"   {device.address}  rssi={adv.rssi:>4}  name={device.name or adv.local_name or '[unnamed]'}"
            + ("  ← 🟢 RING!" if is_ring else ""))
        if is_ring or device.address.upper() == DEFAULT_MAC.upper():
            found_device = device
            stop_event.set()

    scanner = BleakScanner(detection_callback=detection_callback)
    await scanner.start()

    try:
        await asyncio.wait_for(stop_event.wait(), timeout=15.0)
    except asyncio.TimeoutError:
        pass
    finally:
        await scanner.stop()

    if not found_device:
        log("\n❌ Ring not found. Make sure:")
        log("   1. Bluetooth on phone is OFF")
        log("   2. Ring is charged and nearby")
        return

    log(f"\n✅ Found: {found_device.name!r} [{found_device.address}]")
    log(f"🔗 Connecting (using cached device)...\n")

    async with BleakClient(found_device, timeout=20.0) as client:
        log(f"✅ Connected! MTU={client.mtu_size}")
        log("📋 Services:\n")

        write_uuids = []   # all writeable characteristics
        notify_uuids = []

        for service in client.services:
            for ch in service.characteristics:
                u = ch.uuid.lower()
                p = ch.properties
                log(f"   {u}  {p}")
                if "write-without-response" in p or "write" in p:
                    write_uuids.append(u)
                if "notify" in p or "indicate" in p:
                    notify_uuids.append(u)

        # Priority: RXTX write (6e400002) first, then main (de5bf72a)
        # This mirrors what the Flutter app does
        rxtx_write = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
        main_write  = "de5bf72a-d711-4e47-af26-65e3012a5dc7"
        preferred_write = rxtx_write if rxtx_write in write_uuids else (main_write if main_write in write_uuids else (write_uuids[0] if write_uuids else None))
        log(f"✅ write_uuids : {write_uuids}")
        log(f"✅ preferred   : {preferred_write}")
        log(f"✅ notify_uuids: {notify_uuids}\n")

        for nu in notify_uuids:
            await client.start_notify(nu, on_notify)
            log(f"🔔 Subscribed: {nu}")

        log("\n" + "=" * 65)
        log("📡 LISTENING — ДЕЛАЙ ЖЕСТЫ КОЛЬЦОМ!")
        log("👆 Подними запястье / встряхни / двойной тап")
        log("=" * 65)
        log("Legend: 👆❗=жест  🔋=батарея  📡=акселерометр  ❓=новое\n")

        def make_cmd(hex_str):
            b = [int(hex_str[i:i+2], 16) for i in range(0, len(hex_str.replace(" ","")), 2)]
            while len(b) < 15: b.append(0)
            b.append(sum(b) & 0xFF)
            return bytes(b)

        # ── Шаг 1: СНАЧАЛА отключаем все датчики (a102) ─────────────────────
        for wu in write_uuids:
            try:
                await client.write_gatt_char(wu, make_cmd("a102"), response=False)
                log(f"[{ts()}] 🛑 Sent a102 (DISABLE sensors) → {wu}")
                await asyncio.sleep(0.2)
            except Exception as e:
                log(f"[{ts()}] ⚠️  Write failed on {wu}: {e}")

        await asyncio.sleep(0.5)

        # ── Шаг 2: Батарея (только для проверки связи) ───────────────────────
        for wu in write_uuids:
            try:
                await client.write_gatt_char(wu, make_cmd("03"), response=False)
                log(f"[{ts()}] 📤 Sent 03 (battery query) → {wu}")
                await asyncio.sleep(0.2)
            except Exception as e:
                log(f"[{ts()}] ⚠️  Write failed on {wu}: {e}")

        # ── Шаг 3: ПАССИВНЫЙ режим — НЕ включаем a104 ───────────────────────
        log(f"\n⏸️  Датчики ВЫКЛЮЧЕНЫ (a102 отправлен, a104 НЕ отправлен)")
        log(f"   Делай жест кольцом — ищем пассивные пакеты\n")

        log("Нажми Ctrl+C чтобы остановить.\n")
        try:
            await asyncio.sleep(300)
        except (asyncio.CancelledError, KeyboardInterrupt):
            pass

        log(f"\n📊 Итого акселерометр-пакетов: {accel_count}")
        # Всегда выключаем датчики перед дисконнектом
        for wu in write_uuids:
            try:
                await client.write_gatt_char(wu, make_cmd("a102"), response=False)
                log(f"[{ts()}] 🛑 Cleanup: sent a102 → {wu}")
            except: pass
        for nu in notify_uuids:
            try: await client.stop_notify(nu)
            except: pass

if __name__ == "__main__":
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        log("\n⛔ Остановлено.")
    finally:
        _logfile.close()
