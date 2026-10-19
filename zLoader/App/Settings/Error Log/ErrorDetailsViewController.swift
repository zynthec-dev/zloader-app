//
//  ErrorDetailsViewController.swift
//  ZLoader
//
//  Created by Riley Testut on 10/5/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

class ErrorDetailsViewController: UIViewController
{
    var loggedError: LoggedError?

    @IBOutlet private var textView: UITextView!

    override func viewDidLoad()
    {
        super.viewDidLoad()
        view.backgroundColor = .settingsBackground
        textView.backgroundColor = .settingsCard
        textView.textColor = .label
        textView.layer.cornerRadius = ZLoaderSettingsStyle.cardRadius
        textView.clipsToBounds = true
        textView.textContainerInset.top = ZLoaderSettingsStyle.rowPadding
        textView.textContainerInset.bottom = ZLoaderSettingsStyle.rowPadding
        textView.adjustsFontForContentSizeCategory = true


        if let error = self.loggedError?.error
        {
            self.title = error.localizedErrorCode

            let font = self.textView.font ?? UIFont.preferredFont(forTextStyle: .body)
            let detailedDescription = error.formattedDetailedDescription(with: font)
            self.textView.attributedText = detailedDescription
        }
        else
        {
            self.title = NSLocalizedString("Error Details", comment: "")
        }

        self.navigationController?.navigationBar.tintColor = .altPrimary

        self.textView.isScrollEnabled = true
        self.textView.alwaysBounceVertical = true
        self.textView.showsVerticalScrollIndicator = true

        #if !os(tvOS)
        if let sheetController = self.navigationController?.sheetPresentationController
        {
            sheetController.detents = [.medium(), .large()]
            sheetController.selectedDetentIdentifier = .medium
            sheetController.prefersGrabberVisible = true
        }
        #endif
    }

    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()

        self.textView.textContainerInset.left = self.view.layoutMargins.left
        self.textView.textContainerInset.right = self.view.layoutMargins.right
    }
}
