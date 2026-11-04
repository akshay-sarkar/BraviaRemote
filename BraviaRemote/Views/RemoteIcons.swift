import SwiftUI

// Custom glyphs for the keys whose printed icon has no close SF Symbol.
// All are drawn in a unit square and stroked by the caller.

/// Input key: a box open on the left with an arrow entering it.
struct InputGlyph: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        // box (open left side)
        p.move(to: CGPoint(x: r.minX + w * 0.38, y: r.minY + h * 0.18))
        p.addLine(to: CGPoint(x: r.minX + w * 0.90, y: r.minY + h * 0.18))
        p.addLine(to: CGPoint(x: r.minX + w * 0.90, y: r.minY + h * 0.82))
        p.addLine(to: CGPoint(x: r.minX + w * 0.38, y: r.minY + h * 0.82))
        // arrow shaft
        p.move(to: CGPoint(x: r.minX + w * 0.08, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.64, y: r.midY))
        // arrow head
        p.move(to: CGPoint(x: r.minX + w * 0.48, y: r.minY + h * 0.34))
        p.addLine(to: CGPoint(x: r.minX + w * 0.64, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.48, y: r.minY + h * 0.66))
        return p
    }
}

/// Guide key: a rounded box with listing lines.
struct GuideGlyph: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.addRoundedRect(in: CGRect(x: r.minX + w * 0.06, y: r.minY + h * 0.16, width: w * 0.88, height: h * 0.68),
                         cornerSize: CGSize(width: w * 0.1, height: w * 0.1))
        for y in [0.38, 0.5, 0.62] {
            p.move(to: CGPoint(x: r.minX + w * 0.2, y: r.minY + h * y))
            p.addLine(to: CGPoint(x: r.minX + w * 0.32, y: r.minY + h * y))
            p.move(to: CGPoint(x: r.minX + w * 0.42, y: r.minY + h * y))
            p.addLine(to: CGPoint(x: r.minX + w * 0.8, y: r.minY + h * y))
        }
        return p
    }
}

/// Volume rocker centre mark: the rising wedge printed between + and −.
struct VolumeWedge: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

/// OK key: a cross-hair (plus with a gap and a centre dot).
struct ConfirmGlyph: View {
    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let arm = size.width * 0.5
            let gap = size.width * 0.16
            var lines = Path()
            lines.move(to: CGPoint(x: c.x, y: c.y - arm)); lines.addLine(to: CGPoint(x: c.x, y: c.y - gap))
            lines.move(to: CGPoint(x: c.x, y: c.y + gap)); lines.addLine(to: CGPoint(x: c.x, y: c.y + arm))
            lines.move(to: CGPoint(x: c.x - arm, y: c.y)); lines.addLine(to: CGPoint(x: c.x - gap, y: c.y))
            lines.move(to: CGPoint(x: c.x + gap, y: c.y)); lines.addLine(to: CGPoint(x: c.x + arm, y: c.y))
            context.stroke(lines, with: .color(.white), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            let dot = size.width * 0.07
            context.fill(Path(ellipseIn: CGRect(x: c.x - dot, y: c.y - dot, width: dot * 2, height: dot * 2)),
                         with: .color(.white))
        }
    }
}
