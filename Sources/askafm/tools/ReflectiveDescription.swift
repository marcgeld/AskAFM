//
// Copyright 2026 Marcus Gelderman (marcgeld@gmail.com)
// SPDX-License-Identifier: Apache-2.0
//

/// A protocol that provides a default implementation of `description` using reflection to generate a
/// string representation of the conforming type's properties and their values.
protocol ReflectiveDescription: CustomStringConvertible {}

/// Provides a default implementation of the protocol's `description` property
/// that uses Swift's `Mirror` API to reflect on the conforming type's properties and their values.
extension ReflectiveDescription {
    var description: String {
        Mirror(reflecting: self)
            .children
            .compactMap { child in
                guard let label = child.label else { return nil }
                return "\(label): \(child.value)"
            }
            .joined(separator: "\n")
    }
}
