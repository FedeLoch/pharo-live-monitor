Class {
	#name : #BaselineOfLiveMonitor,
	#superclass : #BaselineOf,
	#category : #BaselineOfLiveMonitor
}

{ #category : #baselines }
BaselineOfLiveMonitor >> baseline: spec [

	<baseline>
	spec for: #common do: [
		spec postLoadDoIt: #postLoad.
		spec package: 'LiveMonitor'.
		spec package: 'LiveMonitor-Tests' with: [ spec requires: #( 'LiveMonitor' ) ].
		spec
			group: 'Core' with: #( 'LiveMonitor' );
			group: 'Tests' with: #( 'LiveMonitor-Tests' );
			group: 'default' with: #( 'Core' 'Tests' ) ]
]

{ #category : #actions }
BaselineOfLiveMonitor >> postLoad [
	"Restart so a freshly loaded (or updated) version is the one running."

	(Smalltalk globals at: #LiveMonitor) restartIfEnabled
]
