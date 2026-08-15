# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Install the pinned optional wgpu-native runtime using only Nim and UniImage.
import std/[httpclient, os, strformat, strutils]
import UniImage/compress/deflate

const
  Version = "29.0.1.1"
  MaxEntrySize = 1'i64 shl 30
  MaxArchiveOutput = 2'i64 shl 30

proc u16(data: string; at: int): int =
  if at < 0 or at + 2 > data.len: raise newException(ValueError, "truncated ZIP")
  int(uint8(data[at])) or (int(uint8(data[at + 1])) shl 8)

proc u32(data: string; at: int): uint32 =
  uint32(u16(data, at)) or (uint32(u16(data, at + 2)) shl 16)

proc crc32(data: openArray[byte]): uint32 =
  result = 0xFFFF_FFFF'u32
  for value in data:
    result = result xor uint32(value)
    for _ in 0 ..< 8:
      result = (result shr 1) xor
        (if (result and 1) != 0: 0xEDB8_8320'u32 else: 0'u32)
  result = not result

proc safeRelativePath(name: string): string =
  result = name.replace('\\', '/')
  if result.len == 0 or result.isAbsolute or result.contains("\0") or
      result.contains(':'):
    raise newException(ValueError, "unsafe ZIP path")
  for part in result.split('/'):
    if part == "..": raise newException(ValueError, "unsafe ZIP path")

proc writeBytes(path: string; data: openArray[byte]) =
  var output = open(path, fmWrite)
  defer: output.close()
  if data.len > 0 and output.writeBuffer(unsafeAddr data[0], data.len) != data.len:
    raise newException(IOError, "short write: " & path)

proc extractZip(archive, destination: string) =
  let data = readFile(archive)
  var at = 0
  var totalOutput = 0'i64
  while at + 4 <= data.len and u32(data, at) == 0x0403_4B50'u32:
    if at + 30 > data.len: raise newException(ValueError, "truncated ZIP header")
    let
      flags = u16(data, at + 6)
      compressionMethod = u16(data, at + 8)
      expectedCrc = u32(data, at + 14)
      compressedSize = int(u32(data, at + 18))
      outputSize = int(u32(data, at + 22))
      nameLength = u16(data, at + 26)
      extraLength = u16(data, at + 28)
      contentAt = at + 30 + nameLength + extraLength
    if (flags and 1) != 0 or (flags and 8) != 0:
      raise newException(ValueError, "unsupported ZIP flags")
    totalOutput += outputSize.int64
    if outputSize.int64 > MaxEntrySize or totalOutput > MaxArchiveOutput or
        contentAt < at or
        contentAt + compressedSize > data.len:
      raise newException(ValueError, "invalid ZIP entry size")
    let name = safeRelativePath(data[at + 30 ..< at + 30 + nameLength])
    let target = destination / name
    if name.endsWith('/'):
      createDir(target)
    else:
      createDir(target.parentDir)
      var content: seq[byte]
      case compressionMethod
      of 0:
        content = newSeq[byte](compressedSize)
        for i in 0 ..< compressedSize: content[i] = byte(data[contentAt + i])
      of 8:
        var compressed = newSeq[byte](compressedSize)
        for i in 0 ..< compressedSize:
          compressed[i] = byte(data[contentAt + i])
        content = inflate(compressed, maxOutput = outputSize.int64)
      else:
        raise newException(ValueError, "unsupported ZIP compression method")
      if content.len != outputSize or crc32(content) != expectedCrc:
        raise newException(ValueError, "corrupt ZIP entry: " & name)
      writeBytes(target, content)
    at = contentAt + compressedSize

proc targetName(): string =
  let arch = when defined(arm64): "aarch64"
    elif defined(amd64): "x86_64"
    else: quit("unsupported WGPU architecture", 1)
  when defined(macosx): "macos-" & arch
  elif defined(linux): "linux-" & arch
  elif defined(windows): "windows-" & arch & "-msvc"
  else: quit("unsupported WGPU platform", 1)

proc main() =
  let
    target = targetName()
    destination = ".deps" / "wgpu" / Version / target
  if destination.dirExists:
    echo destination
    return
  let
    asset = "wgpu-" & target & "-release.zip"
    url = &"https://github.com/gfx-rs/wgpu-native/releases/download/v{Version}/{asset}"
    staging = destination & ".installing"
    archive = staging & ".zip"
  if staging.dirExists or archive.fileExists:
    quit("stale WGPU installation staging path: " & staging, 1)
  createDir(destination.parentDir)
  try:
    var client = newHttpClient()
    defer: client.close()
    client.downloadFile(url, archive)
    createDir(staging)
    extractZip(archive, staging)
    let tagFile = staging / "wgpu-native-meta" / "wgpu-native-git-tag"
    if not tagFile.fileExists or tagFile.readFile.strip != "v" & Version:
      raise newException(ValueError,
          "downloaded WGPU archive has an unexpected version")
    moveDir(staging, destination)
  finally:
    if archive.fileExists: removeFile(archive)
    if staging.dirExists: removeDir(staging)
  echo destination

main()
