"
I am the Live Monitor panel in the World. I keep my bottom left corner anchored (by default
in the bottom left corner of the World) and grow upwards when there is more to say.

- '-' button: minimize to a tiny tab; click the tab to restore
- drag: move
- right click: menu (census, reset position, hide)

My step is also the heartbeat that tells the monitor the UI process is alive.
"
Class {
	#name : #LMMonitorMorph,
	#superclass : #Morph,
	#instVars : [
		'monitor',
		'anchor',
		'dragOffset',
		'dragStart',
		'shownVersion'
	],
	#category : #LiveMonitor
}

{ #category : #'instance creation' }
LMMonitorMorph class >> on: aMonitor [

	^ self new setMonitor: aMonitor
]

{ #category : #stepping }
LMMonitorMorph class >> stepMs [

	^ 50
]

{ #category : #accessing }
LMMonitorMorph >> anchor [

	^ anchor
]

{ #category : #layout }
LMMonitorMorph >> defaultAnchor [
	"Bottom left corner of the World, above the taskbar"

	| world |
	world := self world ifNil: [ self currentWorld ].
	^ world bounds bottomLeft + (10 @ -40)
]

{ #category : #drawing }
LMMonitorMorph >> drawOn: aCanvas [

	[ monitor painter draw: monitor on: aCanvas in: self bounds ]
		on: Error
		do: [ :error |
			aCanvas fillRectangle: self bounds color: LMPanelPainter background.
			aCanvas
				drawString: 'live monitor: ' , error messageText asString
				in: (self bounds insetBy: 6)
				font: nil
				color: LMPanelPainter red ]
]

{ #category : #layout }
LMMonitorMorph >> fitToContents [

	| bounds |
	bounds := self panelBounds.
	bounds = self bounds ifFalse: [ self bounds: bounds ]
]

{ #category : #'event handling' }
LMMonitorMorph >> handlesMouseDown: anEvent [

	^ true
]

{ #category : #initialization }
LMMonitorMorph >> initialize [

	super initialize.
	self color: Color transparent.
	shownVersion := -1
]

{ #category : #layout }
LMMonitorMorph >> keepOnTop [
	"Stay above windows, but let menus and dialogs that are not windows go over us"

	| siblings index |
	owner ifNil: [ ^ self ].
	siblings := owner submorphs.
	index := siblings indexOf: self.
	index <= 1 ifTrue: [ ^ self ].
	((siblings first: index - 1) anySatisfy: [ :each | each isSystemWindow ]) ifTrue: [ self comeToFront ]
]

{ #category : #accessing }
LMMonitorMorph >> monitor [

	^ monitor
]

{ #category : #'event handling' }
LMMonitorMorph >> mouseDown: anEvent [

	anEvent yellowButtonPressed ifTrue: [ ^ self openMenu: anEvent ].
	dragStart := anEvent position.
	dragOffset := anEvent position - self position
]

{ #category : #'event handling' }
LMMonitorMorph >> mouseMove: anEvent [

	dragOffset ifNil: [ ^ self ].
	self position: anEvent position - dragOffset.
	anchor := self bottomLeft
]

{ #category : #'event handling' }
LMMonitorMorph >> mouseUp: anEvent [
	"A click (not a drag) on the tab restores the panel; on the '-' button it minimizes it"

	| clicked |
	clicked := dragStart notNil and: [ (anEvent position distanceTo: dragStart) < 3 ].
	dragStart := nil.
	dragOffset := nil.
	clicked ifFalse: [ ^ self ].
	monitor minimized
		ifTrue: [ self toggleMinimized ]
		ifFalse: [
			((monitor painter minimizeButtonOf: monitor in: self bounds) ifNil: [ false ] ifNotNil: [ :button |
				 button containsPoint: anEvent position ]) ifTrue: [ self toggleMinimized ] ]
]

{ #category : #menu }
LMMonitorMorph >> openMenu: anEvent [

	| menu |
	menu := MenuMorph new.
	menu
		add: 'Object census (what grew since last census)' target: monitor selector: #requestCensus;
		add: (monitor minimized
				 ifTrue: [ 'Restore panel' ]
				 ifFalse: [ 'Minimize to a tab' ])
		target: self
		selector: #toggleMinimized;
		add: 'Back to the corner' target: self selector: #resetPosition;
		addLine;
		add: 'Stop Live Monitor' target: LiveMonitor selector: #stop.
	menu popUpEvent: anEvent in: self world
]

{ #category : #layout }
LMMonitorMorph >> panelBounds [
	"Where the panel should be: bottom left at the anchor, inside the World"

	| extent bounds world |
	extent := monitor painter extentFor: monitor.
	bounds := (anchor ifNil: [ self defaultAnchor ]) - (0 @ extent y) extent: extent.
	world := self world ifNil: [ ^ bounds rounded ].
	^ (bounds translatedToBeWithin: world bounds) rounded
]

{ #category : #layout }
LMMonitorMorph >> resetPosition [

	anchor := self defaultAnchor.
	self fitToContents
]

{ #category : #actions }
LMMonitorMorph >> toggleMinimized [

	monitor toggleMinimized.
	self setBalloonText: (monitor minimized ifTrue: [ 'Live Monitor: click to open, drag to move' ] ifFalse: [ nil ]).
	self fitToContents.
	self changed
]

{ #category : #initialization }
LMMonitorMorph >> setMonitor: aMonitor [

	monitor := aMonitor.
	monitor minimized ifTrue: [ self setBalloonText: 'Live Monitor: click to open, drag to move' ].
	self bounds: self panelBounds
]

{ #category : #stepping }
LMMonitorMorph >> step [

	monitor heartbeat.
	anchor ifNil: [ anchor := self defaultAnchor ].
	monitor takeDirectPaintRect ifNotNil: [ :rect |
		"Repair what the monitor painted while the UI was frozen"
		self world ifNotNil: [ :world | world invalidRect: rect ] ].
	self keepOnTop.
	monitor version = shownVersion ifTrue: [ ^ self ].
	shownVersion := monitor version.
	self fitToContents.
	self changed
]

{ #category : #stepping }
LMMonitorMorph >> stepTime [

	^ self class stepMs
]

{ #category : #stepping }
LMMonitorMorph >> wantsSteps [

	^ true
]
