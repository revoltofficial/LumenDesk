import SwiftUI

struct LaserPreviewFrame {
    var lines: [[MotionPoint]] = []
    var colour: Int = 0
    var intensity: Double = 0
    var scanProgress: Double = 0
}
enum LaserPreviewGeometry {
    static let knownPatterns = [116,127,135,145,94,100]
    static func sample(state: FixtureState, seconds: Double, beats: Double) -> LaserPreviewFrame {
        guard state.dimmer.isFinite, state.dimmer > 0, let bytes = state.laserDMX, bytes.count == 9, bytes[0] >= 50, seconds.isFinite, beats.isFinite else { return LaserPreviewFrame() }
        let mode = Int(bytes[0])
        let automatic = mode < 150
        let pattern = automatic ? knownPatterns[Int(abs(seconds/8).truncatingRemainder(dividingBy: 6))] : Int(bytes[1])
        guard knownPatterns.contains(pattern) else { return LaserPreviewFrame() }
        let dynamic = mode < 150 || mode >= 200
        let speed = 0.3 + Double(bytes[5])/255*1.7
        let angle = dynamic ? seconds*speed : 0
        let size = 0.35 + Double(bytes[6])/255*0.65
        func offset(_ raw: UInt8) -> Double { raw <= 10 ? 0 : (Double(raw)-133)/244 }
        let ox = offset(bytes[2]), oy = offset(bytes[3])
        var lines: [[MotionPoint]] = []
        let offsets: [Double] = pattern == 127 || pattern == 145 ? [-0.3,0.3] : [0]
        for offset in offsets {
            var line: [MotionPoint] = []
            for step in 0...48 {
                let t = Double(step)/24-1
                var x = t, y = offset
                if pattern == 135 || pattern == 145 { x = offset; y = t }
                if pattern == 94 { y = t*0.75 }
                if pattern == 100 { x = t*cos(angle); y = t*sin(angle) }
                if dynamic && pattern != 100 { y += 0.12*sin(angle) }
                line.append(MotionPoint(x: min(1,max(-1,x*size+ox)),y: min(1,max(-1,y*size+oy))))
            }
            lines.append(line)
        }
        let pulse = mode < 100 ? 0.35+0.65*(sin(beats*2*Double.pi)+1)/2 : 1
        let progress = dynamic ? (seconds*(1+Double(bytes[4])/64)).truncatingRemainder(dividingBy: 1) : 0.5
        return LaserPreviewFrame(lines: lines,colour: Int(bytes[7]),intensity: min(1,state.dimmer)*pulse,scanProgress: abs(progress))
    }
    static func colour(slot: Int, hue: Double) -> Color {
        switch slot {
        case 0: return EffectColor.hue(hue-floor(hue)).color
        case 2: return .white
        case 4: return .purple
        case 6: return .cyan
        case 8: return .green
        case 10: return .blue
        case 12: return .red
        default: return .gray
        }
    }
}
struct LaserPatternPreview: View {
    var frame: LaserPreviewFrame
    var body: some View {
        Canvas { context,size in
            for line in frame.lines {
                for i in 1..<line.count {
                    let a = line[i-1], b = line[i]
                    var path = Path(); path.move(to: CGPoint(x:(a.x+1)*size.width/2,y:(1-a.y)*size.height/2)); path.addLine(to: CGPoint(x:(b.x+1)*size.width/2,y:(1-b.y)*size.height/2))
                    context.stroke(path,with: .color(LaserPreviewGeometry.colour(slot: frame.colour,hue: Double(i)/Double(line.count)).opacity(frame.intensity)),lineWidth: 1.5)
                }
                let point = line[min(line.count-1,Int(frame.scanProgress*Double(line.count-1)))]
                let q = CGPoint(x:(point.x+1)*size.width/2,y:(1-point.y)*size.height/2)
                context.fill(Path(ellipseIn: CGRect(x:q.x-2,y:q.y-2,width:4,height:4)),with: .color(.white.opacity(frame.intensity)))
            }
        }.background(.black.opacity(0.6),in: RoundedRectangle(cornerRadius: 6)).accessibilityLabel("Schematic animated laser pattern")
    }
}
struct LaserStageBeams: View {
    @EnvironmentObject var store: LightingStore
    var body: some View {
        Canvas { context,size in
            for fixture in store.project.fixtures where fixture.resolvedProfile.isLaser {
                let frame = LaserPreviewGeometry.sample(state: store.renderedState(for: fixture.id),seconds: store.phase,beats: store.tempoClock.beats)
                guard frame.intensity > 0 else { continue }
                let origin = CGPoint(x:max(48,min(size.width-48,fixture.x*size.width)),y:max(58,min(size.height-68,fixture.y*size.height)))
                func project(_ point: MotionPoint) -> CGPoint { CGPoint(x: origin.x+point.x*size.width*0.18,y: origin.y+100+point.y*size.height*0.15) }
                for line in frame.lines {
                    for i in 1..<line.count {
                        let color = LaserPreviewGeometry.colour(slot: frame.colour,hue: Double(i)/Double(line.count))
                        var trace = Path(); trace.move(to: project(line[i-1])); trace.addLine(to: project(line[i]))
                        context.stroke(trace,with: .color(color.opacity(frame.intensity*0.85)),lineWidth: 1.3)
                        if i.isMultiple(of: 6) {
                            var ray = Path(); ray.move(to: origin); ray.addLine(to: project(line[i]))
                            context.stroke(ray,with: .color(color.opacity(frame.intensity*0.12)),lineWidth: 0.6)
                        }
                    }
                    let point = line[min(line.count-1,Int(frame.scanProgress*Double(line.count-1)))]
                    var ray = Path(); ray.move(to: origin); ray.addLine(to: project(point))
                    context.stroke(ray,with: .color(LaserPreviewGeometry.colour(slot:frame.colour,hue:frame.scanProgress).opacity(frame.intensity*0.7)),lineWidth: 1)
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
