//
//  ImageLoadingProtocol.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import UIKit

protocol ImageLoadingProtocol {
    func loadImage(from url: URL?) async -> UIImage?
}
