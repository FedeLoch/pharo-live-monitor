# Pharo Live Monitor

A tiny always-on activity monitor for your Pharo image. It **keeps updating even when the UI thread is frozen**, and tells you which method is looping and which classes are being created in bulk.

<img src="docs/screenshot.png" width="334" alt="Live Monitor panel while the UI is frozen">

## Install

```smalltalk
Metacello new
	baseline: 'LiveMonitor';
	repository: 'github://FedeLoch/pharo-live-monitor:main/src';
	load.
```

That's it: the panel appears in the bottom-left corner and stays on, including after image restarts.

## Use

- **–** minimizes it to a tiny status tab; click the tab to bring it back. If the UI freezes, the full panel pops up on its own.
- Drag it anywhere. Right-click for *object census*, *back to the corner* and *stop*.
- Try it: `LMExamples allocationStorm` (freezes the UI for 8s).
- `LiveMonitor stop` / `LiveMonitor start`, or *Debug ▸ Profiling ▸ Toggle Live Monitor*.

## When can it stop?

The sampler runs at priority 79, so busy UI code, code frozen mid-drawing, and processes you fork at any priority up to 79 can't stop it. Only code at priority 80 (`valueUnpreemptively`) or a long primitive, FFI call or GC blocks the whole VM. Afterwards the panel shows *whole image blocked 6.0s*. Tested on Pharo 13 and 14.

## Overhead

About **1–2%** of CPU while idle. The panel shows its own live cost as `self x%`. In on/off benchmarks (Pharo 13, Apple Silicon, ~1s CPU-bound and allocation-heavy workloads), the difference stayed inside run-to-run noise (−7% to +6%). While the UI is frozen it does extra work (stack sampling, and an object census budgeted at about 3%), which is when you need it.
