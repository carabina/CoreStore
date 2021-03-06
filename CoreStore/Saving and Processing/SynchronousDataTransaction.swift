//
//  SynchronousDataTransaction.swift
//  CoreStore
//
//  Copyright (c) 2015 John Rommel Estropia
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

import Foundation
import CoreData
import GCDKit


// MARK: - SynchronousDataTransaction

/**
The `SynchronousDataTransaction` provides an interface for `NSManagedObject` creates, updates, and deletes. A transaction object should typically be only used from within a transaction block initiated from `DataStack.beginSynchronous(_:)`, or from `CoreStore.beginSynchronous(_:)`.
*/
public final class SynchronousDataTransaction: BaseDataTransaction {
    
    // MARK: Public
    
    /**
    Saves the transaction changes and waits for completion synchronously. This method should not be used after the `commit()` method was already called once.
    */
    public func commit() {
        
        CoreStore.assert(self.transactionQueue.isCurrentExecutionContext(), "Attempted to commit a \(typeName(self)) outside its designated queue.")
        CoreStore.assert(!self.isCommitted, "Attempted to commit a \(typeName(self)) more than once.")
        
        self.isCommitted = true
        self.result = self.context.saveSynchronously()
    }
    
    /**
    Begins a child transaction synchronously where `NSManagedObject` creates, updates, and deletes can be made. This method should not be used after the `commit()` method was already called once.
    
    :param: closure the block where creates, updates, and deletes can be made to the transaction. Transaction blocks are executed serially in a background queue, and all changes are made from a concurrent `NSManagedObjectContext`.
    :returns: a `SaveResult` value indicating success or failure, or `nil` if the transaction was not comitted synchronously
    */
    public func beginSynchronous(closure: (transaction: SynchronousDataTransaction) -> Void) -> SaveResult? {
        
        CoreStore.assert(self.transactionQueue.isCurrentExecutionContext(), "Attempted to begin a child transaction from a \(typeName(self)) outside its designated queue.")
        CoreStore.assert(!self.isCommitted, "Attempted to begin a child transaction from an already committed \(typeName(self)).")
        
        return SynchronousDataTransaction(
            mainContext: self.context,
            queue: self.childTransactionQueue,
            closure: closure).performAndWait()
    }
    
    
    // MARK: BaseDataTransaction
    
    /**
    Creates a new `NSManagedObject` with the specified entity type.
    
    :param: into the `Into` clause indicating the destination `NSManagedObject` entity type and the destination configuration
    :returns: a new `NSManagedObject` instance of the specified entity type.
    */
    public override func create<T: NSManagedObject>(into: Into<T>) -> T {
        
        CoreStore.assert(!self.isCommitted, "Attempted to create an entity of type <\(T.self)> from an already committed \(typeName(self)).")
        
        return super.create(into)
    }
    
    /**
    Returns an editable proxy of a specified `NSManagedObject`. This method should not be used after the `commit()` method was already called once.
    
    :param: object the `NSManagedObject` type to be edited
    :returns: an editable proxy for the specified `NSManagedObject`.
    */
    public override func edit<T: NSManagedObject>(object: T?) -> T? {
        
        CoreStore.assert(!self.isCommitted, "Attempted to update an entity of type \(typeName(object)) from an already committed \(typeName(self)).")
        
        return super.edit(object)
    }
    
    /**
    Returns an editable proxy of the object with the specified `NSManagedObjectID`. This method should not be used after the `commit()` method was already called once.
    
    :param: into an `Into` clause specifying the entity type
    :param: objectID the `NSManagedObjectID` for the object to be edited
    :returns: an editable proxy for the specified `NSManagedObject`.
    */
    public override func edit<T: NSManagedObject>(into: Into<T>, _ objectID: NSManagedObjectID) -> T? {
        
        CoreStore.assert(!self.isCommitted, "Attempted to update an entity of type <\(T.self)> from an already committed \(typeName(self)).")
        
        return super.edit(into, objectID)
    }
    
    /**
    Deletes a specified `NSManagedObject`. This method should not be used after the `commit()` method was already called once.
    
    :param: object the `NSManagedObject` type to be deleted
    */
    public override func delete(object: NSManagedObject?) {
        
        CoreStore.assert(!self.isCommitted, "Attempted to delete an entity of type \(typeName(object)) from an already committed \(typeName(self)).")
        
        super.delete(object)
    }
    
    /**
    Deletes the specified `NSManagedObject`'s.
    
    :param: object the `NSManagedObject` type to be deleted
    :param: objects other `NSManagedObject`'s type to be deleted
    */
    public override func delete(object: NSManagedObject?, _ objects: NSManagedObject?...) {
        
        CoreStore.assert(!self.isCommitted, "Attempted to delete an entities from an already committed \(typeName(self)).")
        
        super.delete([object] + objects)
    }
    
    /**
    Deletes the specified `NSManagedObject`'s.
    
    :param: objects the `NSManagedObject`'s type to be deleted
    */
    public override func delete(objects: [NSManagedObject?]) {
        
        CoreStore.assert(!self.isCommitted, "Attempted to delete an entities from an already committed \(typeName(self)).")
        
        super.delete(objects)
    }
    
    /**
    Rolls back the transaction by resetting the `NSManagedObjectContext`. After calling this method, all `NSManagedObjects` fetched within the transaction will become invalid. This method should not be used after the `commit()` method was already called once.
    */
    public override func rollback() {
        
        CoreStore.assert(!self.isCommitted, "Attempted to rollback an already committed \(typeName(self)).")
        
        super.rollback()
    }
    
    
    // MARK: Internal
    
    internal func performAndWait() -> SaveResult? {
        
        self.transactionQueue.sync {
            
            self.closure(transaction: self)
            if !self.isCommitted && self.hasChanges {
                
                CoreStore.log(.Warning, message: "The closure for the \(typeName(self)) completed without being committed. All changes made within the transaction were discarded.")
            }
        }
        return self.result
    }
    
    internal init(mainContext: NSManagedObjectContext, queue: GCDQueue, closure: (transaction: SynchronousDataTransaction) -> Void) {
        
        self.closure = closure
        
        super.init(mainContext: mainContext, queue: queue)
    }
    
    
    // MARK: Private
    
    private let closure: (transaction: SynchronousDataTransaction) -> Void
}
