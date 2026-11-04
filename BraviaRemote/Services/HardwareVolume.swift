import AVFoundation
import MediaPlayer
import SwiftUI

/// Lets the iPhone's physical volume buttons control the TV.
///
/// Watches the audio session's `outputVolume`. Each step up or down is forwarded to the TV, and the
/// phone's own volume is moved back to the middle whenever it nears either end, so both buttons
/// keep producing events. A hidden `MPVolumeView` also stops iOS from showing its volume HUD
/// while the remote is open.
@MainActor
final class HardwareVolumeController: ObservableObject {
    static let settingKey = "hardwareVolumeButtons"

    var onUp: () -> Void = {}
    var onDown: () -> Void = {}

    private weak var slider: UISlider?
    private var observation: NSKeyValueObservation?
    private var lastVolume: Float = 0.5
    private var resetTarget: Float?
    private(set) var isRunning = false

    func attach(_ slider: UISlider) {
        self.slider = slider
    }

    func start() {
        guard !isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            // .ambient + mixWithOthers: never interrupts music or podcasts already playing.
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            return
        }
        isRunning = true
        lastVolume = session.outputVolume
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let volume = change.newValue else { return }
            Task { @MainActor in self?.volumeChanged(to: volume) }
        }
        if lastVolume > 0.9 || lastVolume < 0.1 { recenter() }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        observation?.invalidate()
        observation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func volumeChanged(to volume: Float) {
        if let target = resetTarget, abs(volume - target) < 0.01 {
            resetTarget = nil
            lastVolume = volume
            return
        }
        if volume > lastVolume {
            onUp()
        } else if volume < lastVolume {
            onDown()
        }
        lastVolume = volume
        if volume > 0.9 || volume < 0.1 { recenter() }
    }

    /// Moves the phone volume back to 50% (ignored as a key press).
    private func recenter() {
        guard let slider else { return }
        resetTarget = 0.5
        // MPVolumeView's slider only applies the value on the next run-loop pass.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            slider.setValue(0.5, animated: false)
            slider.sendActions(for: .valueChanged)
        }
    }
}

/// Invisible MPVolumeView. It hides the system volume HUD and gives the controller the slider
/// it needs to recenter the phone volume.
struct HiddenVolumeView: UIViewRepresentable {
    let controller: HardwareVolumeController

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: -200, y: -200, width: 10, height: 10))
        view.alpha = 0.001
        view.isUserInteractionEnabled = false
        Task { @MainActor in
            if let slider = view.subviews.compactMap({ $0 as? UISlider }).first {
                controller.attach(slider)
            }
        }
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
