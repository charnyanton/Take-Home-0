//
//  RemoteImageLoader.swift
//  stackOverflowTestTask
//
//  Created by Anton Charny on 07.04.2026.
//

import UIKit

final class RemoteImageLoader: ImageLoadingProtocol {
    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()

    internal init(session: URLSession) {
        self.session = session
    }

    func loadImage(from url: URL?) async -> UIImage? {
        guard let url else {
            return nil
        }

        if let cachedImage = self.cache.object(forKey: url as NSURL) {
            return cachedImage
        }

        do {
            let (data, _) = try await self.session.data(from: url)
            guard let image = UIImage(data: data) else {
                return nil
            }

            self.cache.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            return nil
        }
    }
}
