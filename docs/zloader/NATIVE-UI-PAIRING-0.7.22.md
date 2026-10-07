# zLoader 0.7.22: native surfaces and separate pairing purposes

Native system background, grouped background, card background, selection surfaces, separators and text replace the accent-derived green surfaces. Light/Dark and system contrast traits drive these colors. The palette setting changes accents only. User Customizations uses a native Form with Sections and labelled Toggles; the accent picker uses a Form/ColorPicker. UIKit Settings retains its existing routes while using consistent inset cards for Credits and regular row typography.

Pairing routes:
- Onboarding: Self-Pairing; start the server, open this device's pairing settings, import its Remote record and attempt its separate Lockdown pairing.
- Pairing File Management: separate Self-Pairing and Remote Wireless Pairing entries.
- Developer Features: Wireless Pairing at the top; removed from Experimental Features.
- Remote Wireless Pairing: retains LAN discovery/server-interface/client-target flows. Does not navigate to this device's Self-Pairing settings, overwrite the store's pairing files or automatically attempt the store's Lockdown pairing. Its generated file is available through an explicit Export action.
- Live Activity return retains the active pairing purpose.

Discovered targets prefer advertised names from TXT records, including NetService records that were previously omitted by the NWBrowser-only name lookup. The target title is prominent and technical addresses are secondary. If a peer does not advertise a readable device name, its available service instance name remains the fallback; no friendly name is fabricated. No manual hostname field was added.

Validation: Release device build, transport/App Group/context tests, pairing-import regression checks, Settings storyboard wiring and project configuration checks, and bootstrap archive integrity. The new pairing-purpose routes, actual LAN discovery and visual Light/Dark behavior still require acceptance testing on hardware. This release does not claim every legacy screen has been rewritten in SwiftUI.
