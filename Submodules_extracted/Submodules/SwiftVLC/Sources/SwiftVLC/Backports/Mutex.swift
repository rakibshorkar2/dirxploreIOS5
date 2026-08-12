//
//  Mutex.swift
//  swift-mutex
//
//  Created by Simon Whitty on 07/09/2024.
//  Copyright 2024 Simon Whitty
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/swhitty/swift-mutex
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#if os(iOS)

import func os.os_unfair_lock_lock
import struct os.os_unfair_lock
import struct os.os_unfair_lock_t
import func os.os_unfair_lock_trylock
import func os.os_unfair_lock_unlock

/// Backports `Synchronization.Mutex` to iOS versions before iOS 18.
struct Mutex<Value: ~Copyable>: ~Copyable {
  private let storage: MutexStorage<Value>

  init(_ initialValue: consuming sending Value) {
    storage = MutexStorage(initialValue)
  }

  borrowing func withLock<Result, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending Result
  ) throws(E) -> sending Result {
    storage.lock()
    defer { storage.unlock() }
    return try body(&storage.value)
  }

  borrowing func withLockIfAvailable<Result, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending Result
  ) throws(E) -> sending Result? {
    guard storage.tryLock() else { return nil }
    defer { storage.unlock() }
    return try body(&storage.value)
  }
}

extension Mutex: @unchecked Sendable where Value: ~Copyable {}

private final class MutexStorage<Value: ~Copyable> {
  private let lockPointer: os_unfair_lock_t
  var value: Value

  init(_ initialValue: consuming Value) {
    lockPointer = .allocate(capacity: 1)
    lockPointer.initialize(to: os_unfair_lock())
    value = initialValue
  }

  func lock() {
    os_unfair_lock_lock(lockPointer)
  }

  func unlock() {
    os_unfair_lock_unlock(lockPointer)
  }

  func tryLock() -> Bool {
    os_unfair_lock_trylock(lockPointer)
  }

  deinit {
    lockPointer.deinitialize(count: 1)
    lockPointer.deallocate()
  }
}

#endif
