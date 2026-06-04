#!/usr/bin/env python3
"""
ring_rate_test.py — диагностика скорости данных BLE-кольца SSR
Подключается к кольцу, подписывается на акселерометр и замеряет Гц.

Установка зависимости (один раз):
    pip install bleak

Запуск:
    python3 ring_rate_test.py
"""

import asyncio
import math
import time
from datetime import datetime
from bleak import BleakScanner, BleakClient

# ── UUID кольца (из ring_ble_manager.dart) ─────────────────────────────────
RXTX_SERVICE       = "6e40fff0-b5a3-f393-e0a9-e50e24dcca9e"
RXTX_WRITE_CHAR    = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
RXTX_NOTIFY_CHAR   = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
MAIN_SERVICE       = "de5bf728-d711-4e47-af26-65e3012a5dc7"
MAIN_WRITE_CHAR    = "de5bf72a-d711-4e47-af26-65e3012a5dc7"
MAIN_NOTIFY_CHAR   = "de5bf729-d711-4e47-af26-65e3012a5dc7"

# MAC кольца (или None для автопоиска по имени)
RING_MAC  = "B0:24:08:02:06:87"
RING_KEYWORDS = ["SSR", "RING"]

# Команда запуска стрима акселерометра (из Dart-кода)
START_STREAM_CMD = bytes.fromhex("a103")   # включить поток акселерометра

# ── Состояние замера ────────────────────────────────────────────────────────
packet_count   = 0
window_start   = time.monotonic()
REPORT_EVERY_S = 2.0   # выводить статистику каждые N секунд

min_mag = float("inf")
max_mag = 0.0
sum_mag = 0.0


def ts() -> str:
    return datetime.now().strftime("%H:%M:%S.%f")[:-3]


def decode_accel_packet(data: bytearray):
    """Декодирует пакет 0xA1/0x03 — то же самое что в Dart-коде."""
    if len(data) < 8 or data[0] != 0xA1 or data[1] != 0x03:
        return None

    # Знаковые 12-бит (sign-extend at 2048) — точно как в Dart
    raw_x = (data[6] << 4) | (data[7] & 0xF)
    raw_y = (data[2] << 4) | (data[3] & 0xF)
    raw_z = (data[4] << 4) | (data[5] & 0xF)

    x = raw_x - 4096 if raw_x >= 2048 else raw_x
    y = raw_y - 4096 if raw_y >= 2048 else raw_y
    z = raw_z - 4096 if raw_z >= 2048 else raw_z

    mag = math.sqrt(x*x + y*y + z*z)
    return x, y, z, mag


def on_notification(sender, data: bytearray):
    global packet_count, window_start, min_mag, max_mag, sum_mag

    decoded = decode_accel_packet(data)
    if decoded is None:
        # Не акселерометр — просто показываем raw байты
        print(f"[{ts()}]  raw: {data.hex()}")
        return

    x, y, z, mag = decoded
    packet_count += 1
    sum_mag  += mag
    min_mag   = min(min_mag, mag)
    max_mag   = max(max_mag, mag)

    now = time.monotonic()
    elapsed = now - window_start

    if elapsed >= REPORT_EVERY_S:
        hz     = packet_count / elapsed
        avg    = sum_mag / packet_count if packet_count else 0
        bar    = "█" * int(hz / 5)
        print(
            f"\n[{ts()}] ── СТАТИСТИКА ({elapsed:.1f}с) ──────────────────────────"
            f"\n  Частота пакетов : {hz:.1f} Гц  {bar}"
            f"\n  Кол-во пакетов  : {packet_count}"
            f"\n  Величина (mag)  : avg={avg:.0f}  min={min_mag:.0f}  max={max_mag:.0f}"
            f"\n  Последнее       : X={x:+5d}  Y={y:+5d}  Z={z:+5d}  |mag|={mag:.0f}"
            f"\n─────────────────────────────────────────────────────────────────\n"
        )
        # Сброс окна
        packet_count = 0
        window_start = now
        min_mag = float("inf")
        max_mag = 0.0
        sum_mag = 0.0
    else:
        # Живая строка каждый пакет (перезаписывается)
        print(
            f"\r[{ts()}]  X={x:+5d}  Y={y:+5d}  Z={z:+5d}  |mag|={mag:6.0f}  "
            f"packets={packet_count}",
            end="", flush=True
        )


async def find_ring():
    """Ищет кольцо по MAC или по имени."""
    print(f"[{ts()}] Сканирование BLE устройств (5 секунд)...")

    # discover() возвращает dict[BLEDevice, AdvertisementData] в новых версиях bleak
    scanner_result = await BleakScanner.discover(timeout=5.0, return_adv=True)
    # scanner_result: dict[address_str, (BLEDevice, AdvertisementData)]
    devices_adv = list(scanner_result.values())  # список (BLEDevice, AdvertisementData)

    # Сначала ищем по MAC
    for d, adv in devices_adv:
        addr = (d.address or "").upper().replace("-", ":")
        if addr == RING_MAC.upper():
            print(f"[{ts()}] ✅ Найдено по MAC: {d.name} [{d.address}]  RSSI={adv.rssi}")
            return d.address

    # Потом по имени
    for d, adv in devices_adv:
        name = (d.name or "").upper()
        if any(kw in name for kw in RING_KEYWORDS):
            print(f"[{ts()}] ✅ Найдено по имени: {d.name} [{d.address}]  RSSI={adv.rssi}")
            return d.address

    print(f"[{ts()}] ❌ Кольцо не найдено. Найденные устройства:")
    for d, adv in sorted(devices_adv, key=lambda x: x[1].rssi or -999, reverse=True):
        print(f"    {(d.name or '<no name>'):<25} [{d.address}]  RSSI={adv.rssi}")
    return None


async def main():
    address = await find_ring()
    if not address:
        return

    print(f"\n[{ts()}] Подключение к {address}...")
    async with BleakClient(address, timeout=10.0) as client:
        print(f"[{ts()}] ✅ Подключено! MTU={client.mtu_size}")

        # Выводим все сервисы/характеристики для диагностики
        print(f"\n[{ts()}] ── GATT СЕРВИСЫ ──────────────────────────────────")
        for service in client.services:
            print(f"  Сервис: {service.uuid}")
            for char in service.characteristics:
                props = ",".join(char.properties)
                print(f"    Char: {char.uuid}  [{props}]")
        print()

        # Подписываемся на уведомления — пробуем оба notify char'а
        subscribed = False
        for notify_uuid in [RXTX_NOTIFY_CHAR, MAIN_NOTIFY_CHAR]:
            try:
                await client.start_notify(notify_uuid, on_notification)
                print(f"[{ts()}] 📡 Подписка на {notify_uuid}")
                subscribed = True
            except Exception as e:
                print(f"[{ts()}] ⚠️  {notify_uuid}: {e}")

        if not subscribed:
            print(f"[{ts()}] ❌ Не удалось подписаться ни на один notify char!")
            return

        # Отправляем команду старта стрима акселерометра
        for write_uuid in [RXTX_WRITE_CHAR, MAIN_WRITE_CHAR]:
            try:
                await client.write_gatt_char(write_uuid, START_STREAM_CMD, response=False)
                print(f"[{ts()}] ▶️  Команда старта стрима отправлена → {write_uuid}")
                break
            except Exception as e:
                print(f"[{ts()}] ⚠️  Запись в {write_uuid}: {e}")

        print(f"\n[{ts()}] Замер частоты данных... (Ctrl+C для выхода)\n")

        try:
            await asyncio.sleep(120)   # ждём 2 минуты, потом выходим
        except asyncio.CancelledError:
            pass
        except KeyboardInterrupt:
            pass

    print(f"\n[{ts()}] Отключено.")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nВыход.")
