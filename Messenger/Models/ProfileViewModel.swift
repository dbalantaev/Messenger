//
//  ProfileViewModel.swift
//  Messenger
//
//  Created by Дмитрий Балантаев on 26.03.2022.
//

import Foundation

enum ProfileViewModelType {
    case info, logout
}
 
struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}
