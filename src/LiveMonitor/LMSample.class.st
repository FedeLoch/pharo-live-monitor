"
I am one immutable measurement window of the image, published by `LiveMonitor`.
Rates are per second, sizes are in bytes, ratios are between 0 and 1.
"
Class {
	#name : #LMSample,
	#superclass : #Object,
	#instVars : [
		'time',
		'cpu',
		'allocRate',
		'heapUsed',
		'heapSize',
		'objects',
		'objectRate',
		'scavengeRate',
		'fullGCs',
		'gcRatio',
		'uiLag',
		'uiBlockedMs',
		'overhead',
		'busyProcess',
		'loopLabel',
		'hotLabel',
		'hotRatio',
		'progress'
	],
	#category : #LiveMonitor
}

{ #category : #accessing }
LMSample >> allocRate [

	^ allocRate ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> allocRate: anObject [

	allocRate := anObject
]

{ #category : #accessing }
LMSample >> busyProcess [

	^ busyProcess
]

{ #category : #accessing }
LMSample >> busyProcess: anObject [

	busyProcess := anObject
]

{ #category : #accessing }
LMSample >> cpu [

	^ cpu ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> cpu: anObject [

	cpu := anObject
]

{ #category : #accessing }
LMSample >> fullGCs [

	^ fullGCs ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> fullGCs: anObject [

	fullGCs := anObject
]

{ #category : #accessing }
LMSample >> gcRatio [

	^ gcRatio ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> gcRatio: anObject [

	gcRatio := anObject
]

{ #category : #accessing }
LMSample >> heapSize [

	^ heapSize ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> heapSize: anObject [

	heapSize := anObject
]

{ #category : #accessing }
LMSample >> heapUsed [

	^ heapUsed ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> heapUsed: anObject [

	heapUsed := anObject
]

{ #category : #accessing }
LMSample >> hotLabel [

	^ hotLabel
]

{ #category : #accessing }
LMSample >> hotLabel: anObject [

	hotLabel := anObject
]

{ #category : #accessing }
LMSample >> hotRatio [

	^ hotRatio ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> hotRatio: anObject [

	hotRatio := anObject
]

{ #category : #testing }
LMSample >> isAllocationStorm [
	"More than 200 MB/s of fresh objects: something is creating garbage in a loop"

	^ self allocRate > (200 * 1024 * 1024)
]

{ #category : #testing }
LMSample >> isBusy [

	^ self cpu > 0.3
]

{ #category : #testing }
LMSample >> isUiBlocked [

	^ self uiBlockedMs > 0
]

{ #category : #accessing }
LMSample >> loopLabel [

	^ loopLabel
]

{ #category : #accessing }
LMSample >> loopLabel: anObject [

	loopLabel := anObject
]

{ #category : #accessing }
LMSample >> objectRate [

	^ objectRate ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> objectRate: anObject [

	objectRate := anObject
]

{ #category : #accessing }
LMSample >> objects [

	^ objects
]

{ #category : #accessing }
LMSample >> objects: anObject [

	objects := anObject
]

{ #category : #accessing }
LMSample >> overhead [

	^ overhead ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> overhead: anObject [

	overhead := anObject
]

{ #category : #accessing }
LMSample >> progress [
	"How far the busy process is in its loops, an LMProgress, or nil"

	^ progress
]

{ #category : #accessing }
LMSample >> progress: anObject [

	progress := anObject
]

{ #category : #accessing }
LMSample >> scavengeRate [

	^ scavengeRate ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> scavengeRate: anObject [

	scavengeRate := anObject
]

{ #category : #accessing }
LMSample >> time [

	^ time
]

{ #category : #accessing }
LMSample >> time: anObject [

	time := anObject
]

{ #category : #accessing }
LMSample >> uiBlockedMs [

	^ uiBlockedMs ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> uiBlockedMs: anObject [

	uiBlockedMs := anObject
]

{ #category : #accessing }
LMSample >> uiLag [

	^ uiLag ifNil: [ 0 ]
]

{ #category : #accessing }
LMSample >> uiLag: anObject [

	uiLag := anObject
]
