Computational Algebra Library
==============================

What is this?
-------------
This library provides data-types and functions to manipulate polynomials.
This is built up with GHC's nice type features.

It contains following things:

* Compute Groebner basis using Buchberger Algorithm
* Ideal membership problem
* Elimination ideal calculation
* Ideal operations
	* Saturation Ideal, Quotient ideal,...

There are two interfaces:

Dependently-typed I/F
:    Arity-paramaterized polynomials. It uses vector representations for monomials.
     `Algebra.Ring.Polynomial` and `Algebra.Algorithms.Groebner`.

Monomorphic wrapper I/F
:    Not-so-dependently-typed interface to wrap dependently-typed ones. `Algebra.Ring.Polynomial.Monomorphic` and `Algebra.Algorithms.Groebner.Monomorphic`.

Due to GHC 7.4.*'s bug, this library contains extra modules and functionalities as follows:

`Monomorphic` data-type and his frieds
:    This is completely separeted as [`monomorphic`](http://hackage.haskell.org/package/monomorphic) package. But due to GHC 7.4.1, which is shipped with latest Haskell Platform, I include the functionality from this library for a while.

Singleton types and functions
:    Because the [`singletons`](http://hackage.haskell.org/package/singletons) package is not available in GHC 7.4.1, I provide limited version of the functionalities of that package in `Algebra.Internal` module. After new HP released, I will entirely rewrite all source codes using `singletons`.

Type-level natural numbers and size-parameterized vectors
:    For the similar reason, I include `SNat` and `Vector` data-type in `Algebra.Internal` module, which is separated as [`sized-vector`](http://hackage.haskell.org/package/sized-vector) package. Their proofs are so messy, so I will entirely rewrite these after new HP released with my unreleased package [`equational-reasoning`](https://github.com/konn/equational-reasoning-in-haskell), which provides the functionalities similar to Agda's EqReasoning.
