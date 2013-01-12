#lang scribble/doc

@(require (for-label formica))

@(require
  scribble/manual
  scribble/eval)

@(define formica-eval
   (let ([sandbox (make-base-eval)])
     (sandbox '(require formica))
     sandbox))

@title{Monads, defined in Formica}

@declare-exporting[formica]

@section{Id}

@defthing[Id monad?] 
The identity monad.

Definition:
@codeblock{return = id
           bind _m _f = (_f _m)}

Examples:
@defs+int[#:eval formica-eval
 ((using-monad Id)
 (define-formal f))
 (return 'x)
 (bind 'x >>= f)]

In the @racket[Id] monad @racket[do] form works like @racket[match-let*] form with ability to produce side effects within calculations:
@interaction[#:eval formica-eval
 (do [x <- 5]
     [y <- 8]
     (displayln x)
     [x <- (+ x y)]
     (list x y))]

@interaction[#:eval formica-eval
 (do [(cons x y) <- '(1 2 3)]
     [(z t) <<- (reverse y)]
     (return (list x y z t)))]

@section{List}

@defthing[List monad-plus?] 
The @racket[List] monad is used for list comprehension and in order to perform calculations with functions, returning more then one value. The main differenece between the @racket[List] and monad @tt{[]} in @emph{Haskell}, is the ability of @racket[List] to operate with any sequences as @racket[for] iterators do.

Definition:
@codeblock{return = list
           bind _m _f = (concat-map _f _m)
           mzero = null
           mplus = concatenate
           type = listable?
           failure = (const null)}

@defproc[(listable? (v Any)) Bool]
Returns @racket[#t] if @racket[v] is a sequence but not the @tech{formal application}.

Examples:
@interaction[#:eval formica-eval
  (listable? '(1 2 3))
  (listable? 4)
  (listable? (stream 1 2 (/ 0)))
  (listable? '(g x y))
  (define-formal g)
  (listable? (g 'x 'y))]

@defproc[(concatenate (s listable?) ...) list?]
Returns a result of @racket[_s ...] concatenation in a form of a list.

Examples:
@interaction[#:eval formica-eval
  (concatenate '(1 2 3) '(a b c))
  (concatenate 4 (stream 'a 'b 'c))
  (concatenate (in-set (set 'x 'y 'z)) (in-value 8))
  (concatenate 1 2 3)]

@defproc[(concat-map (f (any/c -> n/f-list?)) (s listable?)) list?]
Applies @racket[_f] to elements of @racket[_s] and returns the concatenation of results.

Examples:
@interaction[#:eval formica-eval
  (concat-map (λ (x) (list x (- x))) '(1 2 3))
  (concat-map (λ (x) (list x (- x))) 4)]

@defproc[(zip (s listable?) ...) sequence?]
Returns a sequence where each element is a list with as many values as the number of supplied seqs; the values, in order, are the values of each seq. Used to process sequences in parallel, as in @racket[for/list] iterator.

Example of using @racket[zip]:
@interaction[#:eval formica-eval
  (using List
    (do [(list x y) <- (zip '(a b c) 
                            '(1 2 3 4))]
      (return (f x y))))]
The same with @racket[for/list] iterator.
@interaction[#:eval formica-eval
 (for/list ([x '(a b c)]
            [y '(1 2 3 4)])
   (f x y))]

@subsection{Examples}

@def+int[#:eval formica-eval
 (using-monad List)]

Examples of list comprehension
@interaction[#:eval formica-eval
 (collect (sqr x) [x <- '(1 2 3 4)])]

@interaction[#:eval formica-eval
 (collect (sqr x) [x <- '(1 2 3 4)] (odd? x))]

@interaction[#:eval formica-eval
 (collect (cons x y) 
   [x <- '(1 3 4)]
   [y <- '(a b c)])]

@interaction[#:eval formica-eval
 (collect (cons x y) 
   [(list x y) <- '((1 2) (2 4) (3 6) (5 1))]
   (odd? x)
   (< x y))]

In place of a list any sequence could be used, but only a list is produced.
@interaction[#:eval formica-eval
 (collect (sqr x) [x <- 5])]

@interaction[#:eval formica-eval
 (collect (cons x y) 
   [x <- 3] 
   [y <- '(a b c)])]

@interaction[#:eval formica-eval
 (collect (cons x y) 
   [x <- 3] 
   [y <- "abc"])]

Forms @racket[do] and @racket[collect] in the @racket[List] monad work like @racket[for*/list] form:
@interaction[#:eval formica-eval
 (do [x <- 2] 
     [y <- "abc"] 
     (return (cons x y)))
 (for*/list ([x 2] 
             [y "abc"]) 
   (cons x y))]

@interaction[#:eval formica-eval
 (collect (cons x y) 
   [x <- 3] 
   (odd? x) 
   [y <- "abc"])
 (for*/list ([x 3] 
             #:when (odd? x)
             [y "abc"]) 
   (cons x y))]

It is easy to combine parallel and usual monadic processing:
@interaction[#:eval formica-eval
  (using List
    (do [a <- '(x y z)]
        [(list x y) <- (zip "AB" 
                            (in-naturals))]
      (return (f a x y))))]

The use of monad @racket[List] goes beyond the simple list generation. The main purpose of monadic computations is to provide computation with functions which may return more then one value (or fail to produce any). The examples of various applications of this monad could be found in the @filepath{nondeterministic.rkt} file in the @filepath{examples/} folder.

@section{Stream}

@defthing[Stream monad-plus?] 
Like @racket[List] monad, but provides lazy list processing. This monad is equivalent to monad @tt{[]} in @emph{Haskell} and could be used for operating with potentially infinite sequences.

Definition:
@codeblock{return = stream
           bind _m _f = (stream-concat-map _f _m)
           mzero = empty-stream
           mplus = stream-concatenate
           type = listable?
           failure = (const empty-stream)}

@defproc[(stream-concatenate (s listable?) ...) list?]
Returns a result of @racket[_s ...] lazy concatenation in a form of a stream.

Examples:
@interaction[#:eval formica-eval
  (stream->list 
   (stream-concatenate '(1 2 3) '(a b c)))
  (stream->list 
   (stream-concatenate 4 (stream 'a 'b 'c)))
  (stream-ref 
   (stream-concatenate (stream 1 (/ 0)) (in-naturals)) 
   0)
  (stream-ref 
   (stream-concatenate (stream 1 (/ 0)) (in-naturals)) 
   1)]

@defproc[(stream-concat-map (f (any/c -> n/f-list?)) (s listable?)) list?]
Applies @racket[_f] to elements of @racket[_s] and lazily returns the concatenation of results.

Examples:
@interaction[#:eval formica-eval
  (stream->list 
   (stream-concat-map (λ (x) (stream x (- x))) '(1 2 3)))
  (stream->list 
   (stream-concat-map (λ (x) (stream x (- x))) 4))
  (stream-ref 
   (stream-concat-map (λ (x) (stream x (/ x))) '(1 0 3)) 
   0)
  (stream-ref 
   (stream-concat-map (λ (x) (stream x (/ x))) '(1 0 3)) 
   1)
  (stream-ref 
   (stream-concat-map (λ (x) (stream x (/ x))) '(1 0 3)) 
   2)
  (stream-ref 
   (stream-concat-map (λ (x) (stream x (/ x))) '(1 0 3)) 
   3)]