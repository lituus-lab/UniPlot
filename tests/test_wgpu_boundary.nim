# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniColor
import UniPlot
import UniPlot/render/wgpu

suite "WGPU boundary":
  test "scene resources are prepared without loading a GPU runtime":
    let background = parseColor("#ffffff").get
    let scene = initScene(Size(width: 100, height: 80), background)
    let frame = prepareWgpuFrame(scene)
    check frame.size.width == 100
    check not wgpuCapabilities().available
    check WgpuNativeTargetVersion == "29.0.1.1"
