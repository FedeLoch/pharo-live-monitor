"
I am the Pharo Live Monitor: a tiny always-on activity monitor for the whole image.

A sampler process runs at a priority above the UI process, so it keeps working when the UI
process is stuck in a loop. Every tick it looks at the process it just preempted (that is what
the image is busy doing) and every window it publishes an immutable `LMSample` with CPU,
allocation rate, heap, object count, GC and UI latency.

The panel is an `LMMonitorMorph` in the bottom left corner of the World. While the UI process
answers, Morphic draws it as usual. When the UI stops answering, I paint the panel straight
into the OS window myself, so you can see what the frozen image is doing.

Usage:
	LiveMonitor start.
	LiveMonitor stop.
	LiveMonitor toggle.
	LiveMonitor default requestCensus.	""count instances per class and show what grew""
"
Class {
	#name : #LiveMonitor,
	#superclass : #Object,
	#instVars : [
		'process',
		'running',
		'morph',
		'painter',
		'minimized',
		'tickMs',
		'windowMs',
		'historySize',
		'stallThresholdMs',
		'history',
		'historyArray',
		'latest',
		'version',
		'previousCounters',
		'windowStart',
		'windowTicks',
		'busyTicks',
		'busyTally',
		'uiTally',
		'lastHeartbeat',
		'maxUiGap',
		'ownAllocated',
		'ownMicroseconds',
		'objectCount',
		'objectRate',
		'objectCountTime',
		'objectCountInterval',
		'census',
		'censusTime',
		'censusRequested',
		'growth',
		'growthTime',
		'freeze',
		'lastDirectPaint',
		'directPaintRect',
		'directPaints',
		'lastError',
		'lastTick',
		'starvedMs',
		'starvedAt'
	],
	#classVars : [
		'Default',
		'Enabled',
		'Minimized'
	],
	#category : #LiveMonitor
}

{ #category : #accessing }
LiveMonitor class >> default [

	^ Default
]

{ #category : #'class initialization' }
LiveMonitor class >> initialize [

	SessionManager default registerUserClassNamed: self name.
	self restartIfEnabled
]

{ #category : #testing }
LiveMonitor class >> isEnabled [
	"The monitor is on unless someone explicitly stopped it. The choice survives image restarts."

	^ Enabled ifNil: [ true ]
]

{ #category : #testing }
LiveMonitor class >> isRunning [

	^ Default notNil and: [ Default isRunning ]
]

{ #category : #actions }
LiveMonitor class >> restartIfEnabled [

	self isEnabled ifTrue: [ self start ]
]

{ #category : #'system startup' }
LiveMonitor class >> samplerPriority [
	"As high as possible: above the UI, the event loop and anything user code forks, so nothing
	but the VM timer can starve us. Each tick is a few microseconds, so this costs nothing to others.
	Only code at the timer priority (valueUnpreemptively) or a blocking primitive/FFI call can stop us."

	^ Processor timingPriority - 1
]

{ #category : #'system startup' }
LiveMonitor class >> shutDown: isImageQuitting [

	isImageQuitting ifTrue: [ Default ifNotNil: [ :monitor | monitor stopSampling ] ]
]

{ #category : #actions }
LiveMonitor class >> start [

	Enabled := true.
	Default ifNotNil: [ :monitor | monitor stop ].
	Default := self new.
	Default start.
	^ Default
]

{ #category : #'system startup' }
LiveMonitor class >> startUp: isImageStarting [
	"Counters of the VM restart from zero with a new session, so start fresh."

	isImageStarting ifTrue: [ self restartIfEnabled ]
]

{ #category : #actions }
LiveMonitor class >> stop [

	Enabled := false.
	Default ifNotNil: [ :monitor | monitor stop ].
	Default := nil
]

{ #category : #actions }
LiveMonitor class >> toggle [

	self isRunning
		ifTrue: [ self stop ]
		ifFalse: [ self start ]
]

{ #category : #'world menu' }
LiveMonitor class >> worldMenuOn: aBuilder [

	<worldMenu>
	(aBuilder item: #'Toggle Live Monitor')
		parent: #Profiling;
		order: 5;
		help: 'Show or hide the Pharo Live Monitor panel.';
		action: [ self toggle ]
]

{ #category : #sampling }
LiveMonitor >> allocatedBytes [
	"Total bytes allocated by the VM since start up."

	^ Smalltalk vm parameterAt: 34
]

{ #category : #sampling }
LiveMonitor >> closeWindowAt: now [

	| counters elapsed sample stalled |
	counters := self readCounters.
	elapsed := now - windowStart max: 1.
	self countObjectsIfDueAt: now.
	stalled := self isUiStalledAt: now.
	sample := LMSample new
		          time: now;
		          cpu: (windowTicks = 0
				           ifTrue: [ 0 ]
				           ifFalse: [ busyTicks / windowTicks ]);
		          allocRate: ((counters at: 1) - (previousCounters at: 1) - ownAllocated max: 0) * 1000 / elapsed;
		          heapUsed: (counters at: 2) - (counters at: 3);
		          heapSize: (counters at: 2);
		          objects: objectCount;
		          objectRate: objectRate;
		          scavengeRate: (counters at: 4) - (previousCounters at: 4) * 1000 / elapsed;
		          fullGCs: (counters at: 6) - (previousCounters at: 6);
		          gcRatio: ((counters at: 5) + (counters at: 7) - (previousCounters at: 5) - (previousCounters at: 7)) / elapsed;
		          uiLag: (maxUiGap - LMMonitorMorph stepMs max: 0);
		          uiBlockedMs: (stalled
				           ifTrue: [ now - lastHeartbeat ]
				           ifFalse: [ 0 ]);
		          overhead: ownMicroseconds / (elapsed * 1000);
		          yourself.
	busyTally isEmpty ifFalse: [
		sample
			busyProcess: busyTally processLabel;
			loopLabel: busyTally loopLabel;
			hotLabel: busyTally hotLabel;
			hotRatio: busyTally hotRatio ].
	self updateFreezeWith: sample stalled: stalled at: now.
	history addLast: sample.
	[ history size > historySize ] whileTrue: [ history removeFirst ].
	historyArray := history asArray.
	latest := sample.
	version := version + 1.
	previousCounters := counters.
	self resetWindowAt: now.
	self censusIfDueAt: now
]

{ #category : #census }
LiveMonitor >> censusIfDueAt: now [

	| wanted |
	censusRequested ifTrue: [
		censusRequested := false.
		^ self takeCensusAt: now baselineIfOld: false ].
	wanted := latest uiBlockedMs > 1500 or: [ latest isAllocationStorm ].
	wanted ifFalse: [ ^ self ].
	(censusTime notNil and: [ now - censusTime < self censusInterval ]) ifTrue: [ ^ self ].
	self takeCensusAt: now baselineIfOld: true
]

{ #category : #census }
LiveMonitor >> censusInterval [
	"Automatic censuses walk the whole heap: keep them under ~3% of the time.
	When the UI is frozen we want answers sooner than for a busy background process."

	| cost |
	cost := census ifNil: [ 0 ] ifNotNil: [ census cost ].
	^ latest isUiBlocked
		  ifTrue: [ cost * 33 max: 2000 ]
		  ifFalse: [ cost * 66 max: 10000 ]
]

{ #category : #sampling }
LiveMonitor >> countObjects [
	"Walk the heap without allocating, so counting does not disturb what we measure."

	| count object |
	count := 0.
	object := Object someObject.
	[ object == 0 ] whileFalse: [
		count := count + 1.
		object := object nextObject ].
	^ count
]

{ #category : #sampling }
LiveMonitor >> countObjectsIfDueAt: now [

	| start count cost |
	(objectCountTime notNil and: [ now - objectCountTime < objectCountInterval ]) ifTrue: [ ^ self ].
	start := Time millisecondClockValue.
	count := self countObjects.
	cost := Time millisecondClockValue - start.
	"Keep the heap walk around 1% of the time, whatever the image size"
	objectCountInterval := cost * 100 max: 2000.
	objectCount ifNotNil: [ objectRate := count - objectCount * 1000 / (now - objectCountTime max: 1) ].
	objectCount := count.
	objectCountTime := now
]

{ #category : #accessing }
LiveMonitor >> directPaints [
	"How many times the panel was painted while the UI process was not answering"

	^ directPaints
]

{ #category : #accessing }
LiveMonitor >> freeze [
	"The current or last UI freeze, an LMFreeze, or nil"

	^ freeze
]

{ #category : #accessing }
LiveMonitor >> growth [
	"Instance growth per class from the last census diff: an Array of class -> delta"

	^ growth
]

{ #category : #accessing }
LiveMonitor >> growthAge [

	^ growthTime ifNotNil: [ Time millisecondClockValue - growthTime ]
]

{ #category : #heartbeat }
LiveMonitor >> heartbeat [
	"Sent by the panel from the UI process: the UI is alive."

	| now gap |
	now := Time millisecondClockValue.
	gap := now - lastHeartbeat.
	gap > maxUiGap ifTrue: [ maxUiGap := gap ].
	lastHeartbeat := now
]

{ #category : #accessing }
LiveMonitor >> history [
	"Immutable snapshot of the recent samples, oldest first"

	^ historyArray
]

{ #category : #initialization }
LiveMonitor >> initialize [

	super initialize.
	running := false.
	minimized := Minimized ifNil: [ false ].
	painter := LMPanelPainter new.
	tickMs := 20.
	windowMs := 500.
	historySize := 120.
	stallThresholdMs := 400.
	history := OrderedCollection new.
	historyArray := #(  ).
	latest := LMSample new.
	version := 0.
	lastHeartbeat := Time millisecondClockValue.
	maxUiGap := 0.
	objectCountInterval := 2000.
	censusRequested := false.
	lastDirectPaint := 0.
	directPaints := 0.
	uiTally := LMStackTally new.
	previousCounters := self readCounters.
	self resetWindowAt: Time millisecondClockValue
]

{ #category : #testing }
LiveMonitor >> isRunning [

	^ running
]

{ #category : #testing }
LiveMonitor >> isUiStalledAt: now [

	^ morph notNil and: [ morph world notNil and: [ now - lastHeartbeat > stallThresholdMs ] ]
]

{ #category : #accessing }
LiveMonitor >> lastError [

	^ lastError
]

{ #category : #accessing }
LiveMonitor >> latest [

	^ latest
]

{ #category : #accessing }
LiveMonitor >> minimized [

	^ minimized
]

{ #category : #accessing }
LiveMonitor >> minimized: aBoolean [
	"Remembered for the next start, also across image restarts"

	minimized := aBoolean.
	Minimized := aBoolean.
	version := version + 1
]

{ #category : #accessing }
LiveMonitor >> morph [

	^ morph
]

{ #category : #painting }
LiveMonitor >> paintDirectlyAt: now [
	"The UI process is not answering, so Morphic will not draw. Paint the panel into the
	OS window ourselves, the same way the world renderer shows its own profiling overlay."

	| world renderer osRenderer bounds scale |
	now - lastDirectPaint < 200 ifTrue: [ ^ self ].
	lastDirectPaint := now.
	world := morph world ifNil: [ ^ self ].
	renderer := world worldState worldRenderer.
	(renderer respondsTo: #osWindowRenderer) ifFalse: [ ^ self ].
	osRenderer := renderer osWindowRenderer ifNil: [ ^ self ].
	bounds := morph panelBounds.
	osRenderer drawDuring: [ :canvas | painter draw: self on: canvas in: bounds ].
	scale := renderer canvasScaleFactor.
	(self present: ((bounds scaleBy: scale) expandBy: 1) rounded on: osRenderer) ifFalse: [ ^ self ].
	directPaintRect := directPaintRect
		                   ifNil: [ bounds ]
		                   ifNotNil: [ :rect | rect merge: bounds ].
	directPaints := directPaints + 1
]

{ #category : #painting }
LiveMonitor >> present: aRectangle on: osRenderer [
	"Push aRectangle to the screen now. Never wait for the renderer lock (whoever holds it may be
	the frozen process): if it is taken, answer false and we try again on a later tick.
	Also present when the UI process froze in the middle of a frame (deferred updates)."

	| mutex |
	(osRenderer class allInstVarNames includesAll: #( 'mutex' 'deferUpdates' )) ifFalse: [
		osRenderer updateRectangle: aRectangle.
		^ true ].
	mutex := osRenderer instVarNamed: 'mutex'.
	^ mutex
		  tryEnterCritical: [
			  | deferred |
			  deferred := osRenderer instVarNamed: 'deferUpdates'.
			  osRenderer instVarNamed: 'deferUpdates' put: false.
			  [ osRenderer updateRectangle: aRectangle ] ensure: [
				  osRenderer instVarNamed: 'deferUpdates' put: deferred ].
			  true ]
		  ifLocked: [ false ]
]

{ #category : #sampling }
LiveMonitor >> noteStarvationAt: now [
	"Ticks come every tickMs. A much longer gap means nothing in the image could run, not even us:
	code at the timer priority (valueUnpreemptively), a long primitive, a blocking FFI call or a long GC."

	(lastTick notNil and: [ now - lastTick > 1000 ]) ifTrue: [
		starvedMs := now - lastTick.
		starvedAt := now ].
	lastTick := now
]

{ #category : #accessing }
LiveMonitor >> starvation [
	"Answer how long the monitor itself could not run -> how many ms ago, or nil"

	starvedAt ifNil: [ ^ nil ].
	^ starvedMs -> (Time millisecondClockValue - starvedAt)
]

{ #category : #accessing }
LiveMonitor >> painter [

	^ painter
]

{ #category : #sampling }
LiveMonitor >> readCounters [
	"allocated, heap, free old space, scavenges, scavenge ms, full GCs, full GC ms"

	| vm |
	vm := Smalltalk vm.
	^ {
		  (vm parameterAt: 34).
		  (vm parameterAt: 3).
		  (vm parameterAt: 54).
		  (vm parameterAt: 9).
		  (vm parameterAt: 10).
		  (vm parameterAt: 7).
		  (vm parameterAt: 8) }
]

{ #category : #census }
LiveMonitor >> requestCensus [
	"Ask the sampler to count instances per class at the end of the current window.
	The panel then shows which classes grew since the previous census."

	censusRequested := true
]

{ #category : #sampling }
LiveMonitor >> resetWindowAt: now [

	windowStart := now.
	windowTicks := 0.
	busyTicks := 0.
	busyTally := LMStackTally new.
	maxUiGap := 0.
	ownAllocated := 0.
	ownMicroseconds := 0
]

{ #category : #sampling }
LiveMonitor >> run [

	[ running ] whileTrue: [
		[ self tick ]
			on: Error
			do: [ :error | lastError := error ].
		(Delay forMilliseconds: tickMs) wait ]
]

{ #category : #sampling }
LiveMonitor >> sampleProcesses [

	| preempted ui |
	windowTicks := windowTicks + 1.
	preempted := Processor preemptedProcess.
	(preempted isNil or: [ preempted priority <= Processor lowestPriority ]) ifFalse: [
		busyTicks := busyTicks + 1.
		busyTally addProcess: preempted ].
	(self isUiStalledAt: Time millisecondClockValue) ifFalse: [ ^ self ].
	ui := UIManager default uiProcess.
	ui ifNotNil: [ uiTally addProcess: ui ]
]

{ #category : #accessing }
LiveMonitor >> stallThresholdMs [

	^ stallThresholdMs
]

{ #category : #actions }
LiveMonitor >> start [

	running := true.
	self startPanel.
	self startSampling
]

{ #category : #actions }
LiveMonitor >> startPanel [

	| world |
	world := self currentWorld.
	(world submorphs select: [ :each | each isKindOf: LMMonitorMorph ]) do: [ :each | each delete ].
	morph := LMMonitorMorph on: self.
	morph openInWorld: world
]

{ #category : #actions }
LiveMonitor >> startSampling [

	running := true.
	process := [ self run ]
		           forkAt: self class samplerPriority
		           named: 'LiveMonitor sampler'
]

{ #category : #actions }
LiveMonitor >> stop [

	self stopSampling.
	morph ifNotNil: [ :panel | panel delete ].
	morph := nil
]

{ #category : #actions }
LiveMonitor >> stopSampling [

	running := false.
	process ifNotNil: [ :sampler | sampler == Processor activeProcess ifFalse: [ sampler terminate ] ].
	process := nil
]

{ #category : #heartbeat }
LiveMonitor >> takeDirectPaintRect [
	"Answer the area painted while the UI was frozen, so the panel can ask Morphic to repair it"

	| rect |
	rect := directPaintRect.
	directPaintRect := nil.
	^ rect
]

{ #category : #census }
LiveMonitor >> takeCensusAt: now baselineIfOld: aBoolean [

	| fresh |
	fresh := LMCensus take.
	(census notNil and: [ aBoolean not or: [ now - censusTime < 10000 ] ]) ifTrue: [
		growth := fresh growthSince: census.
		growthTime := now ].
	census := fresh.
	censusTime := now
]

{ #category : #actions }
LiveMonitor >> toggleMinimized [

	self minimized: minimized not
]

{ #category : #sampling }
LiveMonitor >> tick [

	| start allocatedBefore now |
	start := Time microsecondClockValue.
	self noteStarvationAt: Time millisecondClockValue.
	allocatedBefore := self allocatedBytes.
	self sampleProcesses.
	now := Time millisecondClockValue.
	now - windowStart >= windowMs ifTrue: [ self closeWindowAt: now ].
	(self isUiStalledAt: now) ifTrue: [ self paintDirectlyAt: now ].
	ownAllocated := ownAllocated + (self allocatedBytes - allocatedBefore).
	ownMicroseconds := ownMicroseconds + (Time microsecondClockValue - start)
]

{ #category : #sampling }
LiveMonitor >> updateFreezeWith: aSample stalled: stalled at: now [

	stalled ifTrue: [
		(freeze isNil or: [ freeze isOver ]) ifTrue: [ freeze := LMFreeze new ].
		freeze
			durationMs: aSample uiBlockedMs;
			loopLabel: uiTally loopLabel;
			hotLabel: uiTally hotLabel;
			stackLabels: uiTally lastStackLabels.
		^ self ].
	freeze ifNotNil: [ :current | current isOver ifFalse: [ current endedAt: now ] ].
	uiTally isEmpty ifFalse: [ uiTally := LMStackTally new ]
]

{ #category : #accessing }
LiveMonitor >> version [
	"Incremented every time there is something new to show"

	^ version
]
