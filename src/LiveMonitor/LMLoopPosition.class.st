"
I tell where one running loop is: how many iterations are done out of how many.

My key identifies the loop across samples: the loop site and how deep its frame is from the
bottom of the stack. A loop that starts again in a new frame at the same place keeps its key,
like an odometer wheel wrapping around.
"
Class {
	#name : #LMLoopPosition,
	#superclass : #Object,
	#instVars : [
		'key',
		'site',
		'done',
		'total',
		'label'
	],
	#category : #LiveMonitor
}

{ #category : #'instance creation' }
LMLoopPosition class >> key: aKey site: aSite done: aNumber total: anotherNumber [

	^ self new
		  setKey: aKey
		  site: aSite
		  done: aNumber
		  total: anotherNumber
]

{ #category : #accessing }
LMLoopPosition >> current [
	"The iteration running now, counting from 1"

	^ done + 1 min: total
]

{ #category : #accessing }
LMLoopPosition >> done [
	"Iterations completed before the current one"

	^ done
]

{ #category : #accessing }
LMLoopPosition >> fraction [

	^ done / total
]

{ #category : #accessing }
LMLoopPosition >> key [

	^ key
]

{ #category : #accessing }
LMLoopPosition >> label [

	^ label ifNil: [ site label ]
]

{ #category : #accessing }
LMLoopPosition >> label: aString [
	"Name the loop after the block it runs, when that says more than the loop of a library iterator"

	label := aString
]

{ #category : #accessing }
LMLoopPosition >> name [

	^ site name
]

{ #category : #initialization }
LMLoopPosition >> setKey: aKey site: aSite done: aNumber total: anotherNumber [

	key := aKey.
	site := aSite.
	done := aNumber.
	total := anotherNumber
]

{ #category : #accessing }
LMLoopPosition >> site [

	^ site
]

{ #category : #accessing }
LMLoopPosition >> total [

	^ total
]
