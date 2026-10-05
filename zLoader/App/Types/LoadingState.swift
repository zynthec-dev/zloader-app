//
//  LoadingState.swift
//  ZLoader
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

enum LoadingState
{
    case loading
    case finished(Result<Void, Error>)
}
