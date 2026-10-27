import AppKit
import SwiftUI

/// What the Old-School Essentials third-party license (v1.7, in `docs/`)
/// asks the app to say, in one place. Shown in About and in Licenses and
/// Legal; the website says the same.
enum Legal {
    /// The license's required legal text, word for word.
    static let trademark = "Old-School Essentials is a trademark of Necrotic Gnome. The trademark and "
        + "Old-School Essentials logo are used with permission of Necrotic Gnome, under license."
    /// The license's compatibility statement.
    static let requires = "Requires Old-School Essentials."
    /// The license forbids implying the app is official or approved.
    static let independent = "3d6 is an independent app. It isn't an official Old-School "
        + "Essentials product, and isn't affiliated with or approved by Necrotic Gnome."
    static let rulesData = "Game rules data is Open Game Content, used under the Open Game License 1.0a. "
        + "Rules text isn't included: the app has the numbers, and the books have the rules."

    static let yams = """
        Copyright © 2016 JP Simard. MIT License.

        Permission is hereby granted, free of charge, to any person obtaining a copy of this software and \
        associated documentation files (the "Software"), to deal in the Software without restriction, including \
        without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell \
        copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the \
        following conditions:

        The above copyright notice and this permission notice shall be included in all copies or substantial \
        portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT \
        LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO \
        EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER \
        IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR \
        THE USE OR OTHER DEALINGS IN THE SOFTWARE.
        """
}

/// The "Designed for use with Old-School Essentials" logo. The license
/// forbids recolouring it, making it transparent or changing its shape, so
/// it's shown as supplied: the white version in light mode, the black one in
/// dark mode, always at its own aspect ratio. Keep it smaller than the
/// app's name wherever both appear.
struct DesignedForOSELogo: View {
    var width: CGFloat = 150

    var body: some View {
        Image("DesignedForOSE")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: width)
            .accessibilityLabel("Designed for use with Old-School Essentials")
    }
}

/// 3d6 → About 3d6.
struct AboutCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About 3d6") { openWindow(id: AboutView.windowID) }
    }
}

/// The About window: the app, its version, and what the third-party
/// license asks for (the logo, "Requires Old-School Essentials", the
/// trademark line).
struct AboutView: View {
    static let windowID = "about"
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 4) {
                // The app's name is the largest thing here; the logo is smaller.
                Text("3d6")
                    .font(.system(size: 26, weight: .bold))
                Text(version)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            DesignedForOSELogo(width: 150)
            Text(Legal.requires)
                .font(.callout.weight(.semibold))
            VStack(spacing: 8) {
                Text(Legal.independent)
                Text(Legal.trademark)
                Text(Legal.rulesData)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            Button("Licenses and Legal…") { openWindow(id: LicenseView.windowID) }
            Text(copyright)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 380)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? ""
    }
}
