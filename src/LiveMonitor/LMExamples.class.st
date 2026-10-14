"
Misbehaving code to see the Live Monitor at work. Evaluate one of these in a Playground
and watch the panel in the bottom left corner while the UI is frozen.
"
Class {
	#name : #LMExamples,
	#superclass : #Object,
	#category : #LiveMonitor
}

{ #category : #examples }
LMExamples class >> allocationStorm [
	"Freeze the UI for 8 seconds while creating millions of throw-away objects"

	<example>
	self new createPointsFor: 8000
]

{ #category : #examples }
LMExamples class >> busyBackgroundProcess [
	"Spin a background process for 8 seconds: the UI keeps answering, the panel shows who is busy"

	<example>
	[ self new spinFor: 8000 ] forkAt: Processor userBackgroundPriority named: 'busy example'
]

{ #category : #examples }
LMExamples class >> sleepingUI [
	"Block the UI on a wait: the panel shows where it is stuck"

	<example>
	(Delay forSeconds: 6) wait
]

{ #category : #examples }
LMExamples >> createPointsFor: milliseconds [

	| end points |
	end := Time millisecondClockValue + milliseconds.
	[ Time millisecondClockValue < end ] whileTrue: [
		points := OrderedCollection new.
		1 to: 1000 do: [ :i | points add: i @ (i * 2) ] ].
	^ points size
]

{ #category : #examples }
LMExamples >> spinFor: milliseconds [

	| end sum |
	end := Time millisecondClockValue + milliseconds.
	sum := 0.
	[ Time millisecondClockValue < end ] whileTrue: [ sum := sum + (sum \\ 7) + 1 ].
	^ sum
]
