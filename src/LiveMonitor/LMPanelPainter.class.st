"
I draw the Live Monitor panel on any canvas. I only read immutable data from the monitor
(its latest `LMSample`, its history snapshot, the freeze and census results), so I can be used
from the UI process (Morphic drawing) and from the sampler process (direct painting while the
UI is frozen).
"
Class {
	#name : #LMPanelPainter,
	#superclass : #Object,
	#instVars : [
		'font',
		'lineHeight',
		'charWidth'
	],
	#category : #LiveMonitor
}

{ #category : #colors }
LMPanelPainter class >> amber [

	^ Color r: 251 g: 191 b: 36 range: 255
]

{ #category : #colors }
LMPanelPainter class >> background [

	^ Color r: 17 g: 19 b: 25 range: 255
]

{ #category : #colors }
LMPanelPainter class >> border [

	^ Color r: 42 g: 47 b: 58 range: 255
]

{ #category : #colors }
LMPanelPainter class >> cyan [

	^ Color r: 34 g: 211 b: 238 range: 255
]

{ #category : #colors }
LMPanelPainter class >> dim [

	^ Color r: 120 g: 128 b: 146 range: 255
]

{ #category : #formatting }
LMPanelPainter class >> formatBytes: aNumber [

	| n |
	n := aNumber abs.
	n < 1024 ifTrue: [ ^ aNumber rounded printString , ' B' ].
	n < 1048576 ifTrue: [ ^ (aNumber / 1024 printShowingDecimalPlaces: 1) , ' KB' ].
	n < 1073741824 ifTrue: [ ^ (aNumber / 1048576 printShowingDecimalPlaces: 1) , ' MB' ].
	^ (aNumber / 1073741824 printShowingDecimalPlaces: 2) , ' GB'
]

{ #category : #formatting }
LMPanelPainter class >> formatCount: aNumber [

	| n |
	n := aNumber abs.
	n < 1000 ifTrue: [ ^ aNumber rounded printString ].
	n < 1000000 ifTrue: [ ^ (aNumber / 1000 printShowingDecimalPlaces: 1) , 'K' ].
	^ (aNumber / 1000000 printShowingDecimalPlaces: 2) , 'M'
]

{ #category : #formatting }
LMPanelPainter class >> formatMs: aNumber [

	aNumber < 1000 ifTrue: [ ^ aNumber rounded printString , 'ms' ].
	^ (aNumber / 1000 printShowingDecimalPlaces: 1) , 's'
]

{ #category : #formatting }
LMPanelPainter class >> formatOverhead: aRatio [
	"The monitor's own cost, with one decimal because it is usually below 1%"

	^ (aRatio * 100 printShowingDecimalPlaces: 1) , '%'
]

{ #category : #formatting }
LMPanelPainter class >> formatPercent: aRatio [

	^ (aRatio * 100) rounded printString , '%'
]

{ #category : #formatting }
LMPanelPainter class >> formatSignedCount: aNumber [

	^ (aNumber >= 0
		   ifTrue: [ '+' ]
		   ifFalse: [ '-' ]) , (self formatCount: aNumber abs)
]

{ #category : #colors }
LMPanelPainter class >> green [

	^ Color r: 74 g: 222 b: 128 range: 255
]

{ #category : #colors }
LMPanelPainter class >> pink [

	^ Color r: 244 g: 114 b: 182 range: 255
]

{ #category : #colors }
LMPanelPainter class >> red [

	^ Color r: 248 g: 113 b: 113 range: 255
]

{ #category : #colors }
LMPanelPainter class >> sky [

	^ Color r: 96 g: 165 b: 250 range: 255
]

{ #category : #colors }
LMPanelPainter class >> text [

	^ Color r: 229 g: 231 b: 235 range: 255
]

{ #category : #colors }
LMPanelPainter class >> violet [

	^ Color r: 167 g: 139 b: 250 range: 255
]

{ #category : #drawing }
LMPanelPainter >> clip: aString from: x [
	"Cut aString so it fits between x and the right padding"

	| maxChars |
	maxChars := self width - self padding - x // charWidth max: 1.
	aString size <= maxChars ifTrue: [ ^ aString ].
	^ (aString first: (maxChars - 1 max: 0)) , '…'
]

{ #category : #layout }
LMPanelPainter >> detailLinesFor: aMonitor [
	"Answer the extra lines, as text -> color, explaining what the image is doing"

	| lines sample freeze growth |
	lines := OrderedCollection new.
	sample := aMonitor latest.
	freeze := aMonitor freeze.
	(freeze notNil and: [ freeze isOver not or: [ freeze age < 20000 ] ]) ifTrue: [
		lines add: (freeze isOver
				 ifTrue: [ 'last freeze ' , (self class formatMs: freeze durationMs) , ', '
					 , (self class formatMs: freeze age) , ' ago' ]
				 ifFalse: [ 'UI frozen for ' , (self class formatMs: freeze durationMs) ]) -> self class red.
		freeze loopLabel ifNotNil: [ :label | lines add: '  loop ' , label -> self class text ].
		(freeze hotLabel notNil and: [ freeze hotLabel ~= freeze loopLabel ]) ifTrue: [
			lines add: '  hot  ' , freeze hotLabel -> self class text ].
		freeze isOver ifFalse: [
			(freeze stackLabels first: (freeze stackLabels size min: 4)) do: [ :label |
				lines add: '   | ' , label -> self class dim ] ] ].
	(sample isBusy and: [ sample isUiBlocked not and: [ sample loopLabel notNil ] ]) ifTrue: [
		lines add: 'busy ' , (sample busyProcess ifNil: [ '' ]) , ' ' , (self class formatPercent: sample cpu)
			-> self class amber.
		lines add: '  loop ' , sample loopLabel -> self class text.
		(sample hotLabel notNil and: [ sample hotLabel ~= sample loopLabel ]) ifTrue: [
			lines add: '  hot  ' , sample hotLabel , ' ' , (self class formatPercent: sample hotRatio)
				-> self class text ] ].
	aMonitor starvation ifNotNil: [ :starved |
		starved value < 20000 ifTrue: [
			lines add: 'whole image blocked ' , (self class formatMs: starved key) , ', '
				, (self class formatMs: starved value) , ' ago' -> self class amber.
			lines add: '  priority 80 code, a primitive, FFI or GC' -> self class dim ] ].
	growth := aMonitor growth.
	(growth notNil and: [ growth notEmpty and: [ aMonitor growthAge < 20000 ] ]) ifTrue: [
		lines add: 'new instances (census)' -> self class pink.
		(growth first: (growth size min: 4)) do: [ :each |
			lines add: '  ' , ((self class formatSignedCount: each value) padLeftTo: 7) , ' ' , each key name
				-> self class text ] ].
	^ lines
]

{ #category : #drawing }
LMPanelPainter >> draw: aMonitor on: aCanvas in: aRectangle [

	| bounds |
	bounds := aRectangle rounded.
	aCanvas clipBy: bounds during: [ :canvas |
		| status |
		status := self statusFor: aMonitor latest.
		canvas fillRectangle: bounds color: self class background.
		canvas frameRectangle: bounds width: 1 color: (status value alpha: 0.6).
		canvas fillRectangle: (bounds origin extent: 2 @ bounds height) color: status value.
		(self showsTab: aMonitor)
			ifTrue: [ self drawTab: aMonitor status: status on: canvas in: bounds ]
			ifFalse: [ self drawPanel: aMonitor status: status on: canvas in: bounds ] ]
]

{ #category : #drawing }
LMPanelPainter >> drawHeader: aMonitor status: status on: aCanvas at: aPoint [

	| x statusX button |
	x := aPoint x + self padding.
	self drawDot: status value on: aCanvas at: x @ aPoint y.
	aCanvas
		drawString: 'pharo live  self ' , (self class formatOverhead: (self recentOverheadOf: aMonitor))
		at: x + 12 @ aPoint y
		font: font
		color: self class dim.
	button := self minimizeButtonIn: (aPoint extent: self width @ lineHeight).
	statusX := button left - 4 - (status key size * charWidth).
	aCanvas drawString: status key at: statusX @ aPoint y font: font color: status value.
	aCanvas
		line: button left + 3 @ button center y
		to: button right - 3 @ button center y
		width: 1
		color: self class text
]

{ #category : #drawing }
LMPanelPainter >> drawDot: aColor on: aCanvas at: aPoint [

	aCanvas fillRectangle: (aPoint x @ (aPoint y + (lineHeight - 7 // 2)) extent: 7 @ 7) color: aColor
]

{ #category : #drawing }
LMPanelPainter >> drawPanel: aMonitor status: status on: aCanvas in: bounds [

	| y |
	y := bounds top + self padding.
	self drawHeader: aMonitor status: status on: aCanvas at: bounds left @ y.
	y := y + lineHeight + 2.
	(self rowsFor: aMonitor) do: [ :row |
		self drawRow: row history: aMonitor history on: aCanvas at: bounds left @ y.
		y := y + lineHeight ].
	(self detailLinesFor: aMonitor) ifNotEmpty: [ :lines |
		y := y + 3.
		aCanvas
			line: bounds left + self padding @ (y - 2)
			to: bounds right - self padding @ (y - 2)
			width: 1
			color: self class border.
		lines do: [ :line |
			| x |
			x := bounds left + self padding.
			aCanvas drawString: (self clip: line key from: x - bounds left) at: x @ y font: font color: line value.
			y := y + lineHeight ] ]
]

{ #category : #drawing }
LMPanelPainter >> drawTab: aMonitor status: status on: aCanvas in: bounds [
	"The minimized panel: a status dot and the CPU, enough to notice when something is off"

	| x y |
	x := bounds left + self tabPadding.
	y := bounds top + self tabPadding.
	self drawDot: status value on: aCanvas at: x @ y.
	aCanvas drawString: (self tabTextFor: aMonitor) at: x + 11 @ y font: font color: self class text
]

{ #category : #drawing }
LMPanelPainter >> drawRow: row history: history on: aCanvas at: aPoint [
	"row is { label. value. color. valueBlock. minimum span }"

	| x sparkRect |
	x := aPoint x + self padding.
	aCanvas drawString: (row at: 1) at: x @ aPoint y font: font color: self class dim.
	aCanvas drawString: (row at: 2) at: x + (6 * charWidth) @ aPoint y font: font color: self class text.
	sparkRect := aPoint x + self width - self padding - self sparkWidth @ (aPoint y + 2) extent:
		             self sparkWidth @ (lineHeight - 4).
	self
		drawSpark: (history collect: (row at: 4))
		in: sparkRect
		color: (row at: 3)
		span: (row at: 5)
		on: aCanvas
]

{ #category : #drawing }
LMPanelPainter >> drawSpark: values in: aRectangle color: aColor span: minimumSpan on: aCanvas [
	"Draw the last values as 1px bars, newest on the right. The vertical scale goes from
	the smallest to the biggest value, but never less than minimumSpan so noise stays flat."

	| shown low high span x |
	aCanvas fillRectangle: aRectangle color: (aColor alpha: 0.06).
	values isEmpty ifTrue: [ ^ self ].
	shown := values last: (values size min: self sparkWidth).
	high := shown inject: shown first into: [ :a :b | a max: b ].
	low := minimumSpan < 0
		       ifTrue: [ shown inject: shown first into: [ :a :b | a min: b ] ]
		       ifFalse: [ 0 ].
	span := high - low max: minimumSpan abs.
	x := aRectangle right - shown size.
	shown do: [ :value |
		| h |
		h := (value - low / span * aRectangle height) rounded max: 1.
		aCanvas fillRectangle: (x @ (aRectangle bottom - h) extent: 1 @ h) color: (aColor alpha: 0.85).
		x := x + 1 ]
]

{ #category : #layout }
LMPanelPainter >> extentFor: aMonitor [

	^ (self widthFor: aMonitor) @ (self heightFor: aMonitor)
]

{ #category : #layout }
LMPanelPainter >> heightFor: aMonitor [

	| lines |
	(self showsTab: aMonitor) ifTrue: [ ^ self tabPadding * 2 + lineHeight ].
	lines := 1 + (self rowsFor: aMonitor) size.
	(self detailLinesFor: aMonitor) ifNotEmpty: [ :details | lines := lines + details size ].
	^ self padding * 2 + (lines * lineHeight) + 6
]

{ #category : #layout }
LMPanelPainter >> minimizeButtonIn: aRectangle [
	"The '-' in the top right corner of the panel"

	^ aRectangle right - self padding - 12 @ aRectangle top extent: 12 @ lineHeight
]

{ #category : #layout }
LMPanelPainter >> minimizeButtonOf: aMonitor in: aRectangle [
	"Answer the minimize button area of the panel drawn in aRectangle, nil when showing the tab"

	(self showsTab: aMonitor) ifTrue: [ ^ nil ].
	^ (self minimizeButtonIn: (aRectangle left @ (aRectangle top + self padding) extent: aRectangle width @ lineHeight))
		  expandBy: 4
]

{ #category : #layout }
LMPanelPainter >> showsTab: aMonitor [
	"Minimized, unless the UI is frozen: that is exactly when you want to see the details"

	^ aMonitor minimized and: [ aMonitor latest isUiBlocked not ]
]

{ #category : #layout }
LMPanelPainter >> tabPadding [

	^ 5
]

{ #category : #layout }
LMPanelPainter >> tabTextFor: aMonitor [

	^ self class formatPercent: aMonitor latest cpu
]

{ #category : #layout }
LMPanelPainter >> widthFor: aMonitor [

	(self showsTab: aMonitor) ifFalse: [ ^ self width ].
	"room for the widest text, so the tab does not jitter"
	^ self tabPadding * 2 + 11 + (4 * charWidth)
]

{ #category : #initialization }
LMPanelPainter >> initialize [

	super initialize.
	font := LogicalFont familyName: 'Source Code Pro' pointSize: 8.
	font realFont isNil ifTrue: [ font := StandardFonts codeFont ].
	lineHeight := font height + 1.
	charWidth := font widthOf: $M
]

{ #category : #layout }
LMPanelPainter >> padding [

	^ 8
]

{ #category : #layout }
LMPanelPainter >> recentOverheadOf: aMonitor [
	"The monitor's own cost over the last ~10 seconds, so a census spike is amortized like it really is"

	| recent |
	recent := aMonitor history last: (aMonitor history size min: 20).
	recent isEmpty ifTrue: [ ^ 0 ].
	^ (recent inject: 0 into: [ :sum :each | sum + each overhead ]) / recent size
]

{ #category : #layout }
LMPanelPainter >> rowsFor: aMonitor [
	"Each row: label, value, color, block extracting the history value, minimum span.
	A negative span asks for a min to max scale instead of zero to max."

	| s |
	s := aMonitor latest.
	^ {
		  { 'cpu'. self class formatPercent: s cpu. self class cyan. [ :each | each cpu ]. 1 }.
		  { 'alloc'. (self class formatBytes: s allocRate) , '/s'. self class pink. [ :each | each allocRate ].
		  1048576 }.
		  { 'heap'. self class formatBytes: s heapUsed. self class violet. [ :each | each heapUsed ].
		  -1048576 }.
		  { 'objs'.
		  (s objects
			   ifNil: [ '…' ]
			   ifNotNil: [ :n |
			   (self class formatCount: n) , ' ' , (self class formatSignedCount: s objectRate) , '/s' ]).
		  self class green. [ :each | each objects ifNil: [ 0 ] ]. -1000 }.
		  { 'gc'.
		  (self class formatCount: s scavengeRate) , '/s ' , (self class formatPercent: s gcRatio)
		  , (s fullGCs > 0
			   ifTrue: [ ' FULL' ]
			   ifFalse: [ '' ]).
		  self class amber. [ :each | each gcRatio ]. 0.1 }.
		  { 'ui'.
		  (s isUiBlocked
			   ifTrue: [ 'FROZEN ' , (self class formatMs: s uiBlockedMs) ]
			   ifFalse: [ 'lag ' , (self class formatMs: s uiLag) ]).
		  (s isUiBlocked
			   ifTrue: [ self class red ]
			   ifFalse: [ self class sky ]). [ :each | each uiBlockedMs max: each uiLag ]. 200 } }
]

{ #category : #layout }
LMPanelPainter >> sparkWidth [

	^ 96
]

{ #category : #layout }
LMPanelPainter >> statusFor: aSample [
	"Answer the status text -> color"

	aSample isUiBlocked ifTrue: [ ^ 'FROZEN' -> self class red ].
	aSample isAllocationStorm ifTrue: [ ^ 'ALLOC STORM' -> self class amber ].
	aSample cpu > 0.9 ifTrue: [ ^ 'BUSY' -> self class amber ].
	aSample cpu < 0.05 ifTrue: [ ^ 'idle' -> self class green ].
	^ 'ok' -> self class green
]

{ #category : #layout }
LMPanelPainter >> width [

	^ 300
]
