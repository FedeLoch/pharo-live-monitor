# Pharo Live Monitor

A tiny always-on activity monitor for your Pharo image. It **keeps updating even when the UI thread is frozen**, and tells you which method is looping and which classes are being created in bulk.

<p align="center">
  <img src="docs/demo.gif" width="480" alt="Live Monitor panel updating while the UI is frozen">
</p>

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

## Reading the panel

**Header.** The dot and the word on the right give the overall status:

| Status | Meaning |
|---|---|
| `idle` | CPU below 5% |
| `ok` | normal activity |
| `BUSY` | CPU above 90% |
| `ALLOC STORM` | more than 200 MB/s of new objects: something is creating garbage in a loop |
| `FROZEN` | the UI process hasn't answered for more than 400 ms |

`self x%` is the monitor's own CPU cost, averaged over the last 10 seconds.

**Metrics.** Values are measured over 0.5 s windows. Each sparkline shows the last ~48 s, one bar per window, newest on the right.

| Row | What it measures |
|---|---|
| `cpu` | Share of time the image is running Smalltalk code rather than idling. The monitor checks every 20 ms which process is running. |
| `alloc` | Bytes of new objects allocated per second, from the VM's allocation counter, excluding the monitor's own allocations. |
| `heap` | Memory in use: heap size minus free old space. Includes garbage the GC hasn't collected yet. |
| `objs` | Number of objects in the heap, and its net change per second. Counted by walking the heap every few seconds (more rarely on big images, to stay around 1% cost). |
| `gc` | Young-generation GCs (scavenges) per second and the share of time spent in GC. `FULL` appears when a full GC happened in the window. |
| `ui` | `lag`: how late the UI process answers, beyond its normal 50 ms beat. `FROZEN Ns`: how long it has not answered at all. |

`cpu` bars go from 0 to 100%. `alloc`, `gc` and `ui` bars are scaled from zero to the highest value shown. `heap` and `objs` bars are scaled from their lowest to highest value, so that small changes stay visible.

**Details.** Extra lines appear below the metrics when there is something to explain:

- **`UI frozen for Ns`**, then **`last freeze Ns, Xs ago`** for 20 s after the UI is back.
  - `loop`: the innermost method found on the UI stack in at least 80% of samples. This is where it's spinning, or the call that never returns.
  - `hot`: the method most often at the very top of the stack, where the CPU time actually goes.
  - `| …`: the top of the UI stack at the latest sample.
- **`busy <process> N%`**: when the CPU is above 30% but the UI is responsive, this names the process doing the work, with its own `loop` and `hot` lines.
- **`new instances (census)`**: the classes whose instance count grew the most between the last two object censuses, for example `+43.0K OrderedCollection`. A census runs automatically when the UI has been frozen for 1.5 s or during an allocation storm, and on demand from the right-click menu.
- **`whole image blocked Ns`**: the monitor itself couldn't run for more than a second. Only code at priority 80 (`valueUnpreemptively`), a long primitive, an FFI call or a long GC can do that.

## Overhead

About **1–2%** of CPU while idle. The panel shows its own live cost as `self x%`. In on/off benchmarks (Pharo 13, Apple Silicon, ~1s CPU-bound and allocation-heavy workloads), the difference stayed inside run-to-run noise (−7% to +6%). While the UI is frozen it does extra work (stack sampling, and an object census budgeted at about 3%), which is when you need it.
