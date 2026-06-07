# -*- mode: python ; coding: utf-8 -*-
"""
OneClickMCP v2.0 PyInstaller spec (主人 2026-06-07 08:25 立)
= v1.7 watchdog + 启动自检 + cloudflared 自动检测
不用 --add-data (cloudflared 不 bundled, 太大, 走 PATH 检测)
"""
import sys
from PyInstaller.utils.hooks import collect_submodules

block_cipher = None

# 收集所有用到的子模块
hiddenimports = collect_submodules('encodings') + [
    'urllib.request',
    'urllib.error',
    'json',
    'base64',
    'ctypes',
    'subprocess',
    'pathlib',
]

a = Analysis(
    ['one_click_mcp.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)
pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,           # --onedir 关键
    name='OneClickMCP',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,                    # 主人电脑无 console 窗口 (三保险修不了 PyInstaller 主进程, 走 console=False)
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    # 资源: 图标 (可选, 主人电脑没指定)
    # icon='OneClickMCP.ico',
)
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='OneClickMCP',
)
