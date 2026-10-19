#!/usr/bin/env python3
"""Static coverage of the shared settings presentation; does not replace a device UI test."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
settings = root / "zLoader/Features/Views/Settings"
menus = []
for path in sorted(settings.rglob("*.swift")):
    source = path.read_text()
    if ".navigationTitle(" in source:
        assert ".zLoaderSettingsPage()" in source, f"Unstyled destination: {path}"
        menus.append(path.relative_to(root).as_posix())
    assert not re.search(r"\bForm\s*\{|\.listStyle\(|\.labelStyle\(\.titleOnly\)", source), path
    assert "listRowBackground(ZLoaderGlassBackground())" not in source, path

source = (settings / "Diagnostics/DeveloperOptionsView.swift").read_text()
start = source.index('Section("Developer Features")')
end = source.index("// Section 1: Logging & Diagnostics", start)
assert source.count('SettingsEntryLabel(title: "Refresh Cache"') == 1
assert 'SettingsEntryLabel(title: "Refresh Cache"' in source[start:end]
assert "List {" in source[:start] and "ZLoaderGlassGroup" not in source[:end]
for name in ["DeveloperOptionsView", "ExperimentalFeaturesView", "OperationsLoggingControlView"]:
    text = (settings / f"Diagnostics/{name}.swift").read_text()
    assert "List {" in text and "ScrollView {" not in text, name
    assert '.labelsHidden()' not in text, f"Toggle label detached from its control: {name}"

for relative in ["Profiles/SelectProfileViewController.swift", "Certificates/SignableCertificatesListViewController.swift"]:
    text = (settings / "Advanced" / relative).read_text()
    assert "ZLoaderSettingsTableStyle.apply(to: self.tableView)" in text
    assert "ZLoaderSettingsTableViewCell" in text

print(f"PASS shared settings style: {len(menus)} menu/detail source files, integrated refresh-cache row, native labelled toggles and UIKit selection menus")
