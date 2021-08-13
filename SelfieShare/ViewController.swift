//
//  ViewController.swift
//  SelfieShare
//
//  Created by Igor Chernyshov on 11.08.2021.
//

import UIKit
import MultipeerConnectivity

final class ViewController: UICollectionViewController {

	// MARK: - Properties
	private var images = [UIImage]()

	private var peerID = MCPeerID(displayName: UIDevice.current.name)
	private var mcSession: MCSession?
	private var mcAdvertiserAssistant: MCAdvertiserAssistant?

	private enum Constants {
		static let serviceType = "ic-selfieShare"
	}

	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()

		title = "Selfie Share"
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(importPicture))
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showConnectionPrompt))

		mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
		mcSession?.delegate = self
	}

	// MARK: - Image Picker
	@objc private func importPicture() {
		let picker = UIImagePickerController()
		picker.allowsEditing = true
		picker.delegate = self
		present(picker, animated: true)
	}

	// MARK: - Sessions
	@objc private func showConnectionPrompt() {
		let alertController = UIAlertController(title: "Connect to others", message: nil, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: "Host a session", style: .default, handler: startHosting))
		alertController.addAction(UIAlertAction(title: "Join a session", style: .default, handler: joinSession))
		alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		present(alertController, animated: true)
	}

	private func startHosting(action: UIAlertAction) {
		guard let mcSession = mcSession else { return }
		mcAdvertiserAssistant = MCAdvertiserAssistant(serviceType: Constants.serviceType, discoveryInfo: nil, session: mcSession)
		mcAdvertiserAssistant?.start()
	}

	private func joinSession(action: UIAlertAction) {
		guard let mcSession = mcSession else { return }
		let mcBrowser = MCBrowserViewController(serviceType: Constants.serviceType, session: mcSession)
		mcBrowser.delegate = self
		present(mcBrowser, animated: true)
	}
}

// MARK: - UICollectionViewDataSource
extension ViewController {

	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		images.count
	}

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageView", for: indexPath)

		if let imageView = cell.viewWithTag(1000) as? UIImageView {
			imageView.image = images[indexPath.item]
		}

		return cell
	}
}

// MARK: - UINavigationControllerDelegate
extension ViewController: UINavigationControllerDelegate {}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate {

	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		guard let image = info[.editedImage] as? UIImage else { return }

		dismiss(animated: true)

		images.insert(image, at: 0)
		collectionView.reloadData()

		guard let mcSession = mcSession, !mcSession.connectedPeers.isEmpty, let imageData = image.pngData() else { return }

		do {
			try mcSession.send(imageData, toPeers: mcSession.connectedPeers, with: .reliable)
		} catch {
			let alertController = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: "OK", style: .default))
			present(alertController, animated: true)
		}
	}
}

// MARK: - MCSessionDelegate
extension ViewController: MCSessionDelegate {

	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		DispatchQueue.main.async { [weak self] in
			if let image = UIImage(data: data) {
				self?.images.insert(image, at: 0)
				self?.collectionView.reloadData()
			}
		}
	}

	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		let stateName: String
		switch state {
		case .connected: stateName = "Connected"
		case .connecting: stateName = "Connecting"
		case .notConnected: stateName = "Not connected"
		@unknown default: stateName = "Unknown state received"
		}
		print("\(stateName): \(peerID.displayName)")
	}

	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCBrowserViewControllerDelegate
extension ViewController: MCBrowserViewControllerDelegate {

	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		dismiss(animated: true)
	}

	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		dismiss(animated: true)
	}
}
