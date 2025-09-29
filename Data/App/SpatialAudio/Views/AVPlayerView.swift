//
//  AVPlayerView.swift
//  Spatial-Audio-Research-ARVR
//
//  Created by Amelia Eckard on 9/25/25.
//

import SwiftUI

struct AVPlayerView: UIViewControllerRepresentable {
    let viewModel: AVPlayerViewModel

    func makeUIViewController(context: Context) -> some UIViewController {
        return viewModel.makePlayerViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }
}
