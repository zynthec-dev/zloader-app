"""Validate Settings storyboard wiring against its Swift controller and resource IDs."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
controller = (root / 'zLoader/App/Settings/SettingsViewController.swift').read_text()
outlets = set(re.findall(r'@IBOutlet\s+(?:private\s+)?(?:weak\s+)?var\s+(\w+)', controller))
actions = set(re.findall(r'(?:@IBAction|@objc)\s+(?:private\s+)?func\s+(\w+)', controller))
for relative in ['zLoader/App/Settings/Settings.storyboard', 'zLoader/App/Settings/tvOS/Settings.storyboard']:
    tree = ET.parse(root / relative)
    ids = {node.get('id') for node in tree.iter() if node.get('id')}
    settings = next(node for node in tree.iter('tableViewController')
                    if node.get('customClass') == 'SettingsViewController')
    for outlet in settings.findall('./connections/outlet'):
        assert outlet.get('property') in outlets, (relative, 'Unknown outlet', outlet.get('property'))
    for action in settings.iter('action'):
        if action.get('destination') == settings.get('id'):
            assert action.get('selector').split(':')[0] in actions, (relative, 'Unknown action', action.get('selector'))
    for node in tree.iter():
        for attribute in ['destination', 'firstItem', 'secondItem', 'textLabel', 'detailTextLabel']:
            if node.get(attribute):
                assert node.get(attribute) in ids, (relative, 'Dangling reference', node.get(attribute))
    assert settings.get('customModule') == 'zLoader'
    print('PASS', relative, 'outlets, selectors, module and resource references')
