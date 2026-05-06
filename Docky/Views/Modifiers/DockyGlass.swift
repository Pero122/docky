//
//  DockyGlass.swift
//  Docky
//
//  Drop-in replacement for `.glassEffect(.regular, in:)` that honors the
//  user's MaterialStyle preference. Use `.dockyGlass(in: shape)` on every
//  surface that should follow the toggle. The main window chrome is
//  intentionally excluded — it has its own gradient/border treatment.
//

import SwiftUI

extension View {
    @ViewBuilder
    func dockyGlass<S: Shape>(in shape: S) -> some View {
        modifier(DockyGlassModifier(shape: AnyShape(shape)))
    }

    @ViewBuilder
    func dockyGlass() -> some View {
        modifier(DockyGlassModifier(shape: AnyShape(Capsule())))
    }
}

private struct DockyGlassModifier: ViewModifier {
    let shape: AnyShape

    func body(content: Content) -> some View {
        // The materialStyle preference is currently stashed; until that work
        // lands again, this modifier always renders Liquid Glass.
        content.glassEffect(.regular, in: shape)
    }
}
