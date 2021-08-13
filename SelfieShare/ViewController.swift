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
		static let textMessage = "textMessage"
	}

	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()

		title = "Selfie Share"

		let connectButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(showConnectionPrompt))
		let peersButton = UIBarButtonItem(image: UIImage(systemName: "person"), style: .plain, target: self, action: #selector(showPeersDidTap))
		navigationItem.leftBarButtonItems = [connectButton, peersButton]

		let addPictureButton = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(importPicture))
		let sendTextButton = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(sendTextDidTap))
		navigationItem.rightBarButtonItems = [addPictureButton, sendTextButton]

		mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
		mcSession?.delegate = self
	}

	// MARK: - Text Sender
	@objc private func sendTextDidTap() {
		let textAlert = UIAlertController(title: "Send text", message: nil, preferredStyle: .alert)
		textAlert.addTextField()
		textAlert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
			self?.send(text: textAlert.textFields?.first?.text)
		})
		textAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		present(textAlert, animated: UIView.areAnimationsEnabled)
	}

	private func send(text: String?) {
		guard let text = text else { return }
		let myPeerID = mcSession?.myPeerID.displayName ?? "unknown user"
		let textToSend = "\(Constants.textMessage);\(myPeerID);\(text)"
		let textData = Data(textToSend.utf8)
		send(data: textData)
	}

	// MARK: - Data Sender
	private func send(data: Data) {
		guard let session = mcSession, !session.connectedPeers.isEmpty else { return }
		do {
			try session.send(data, toPeers: session.connectedPeers, with: .reliable)
		} catch {
			let alertController = UIAlertController(title: "Send error", message: error.localizedDescription, preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: "OK", style: .default))
			present(alertController, animated: UIView.areAnimationsEnabled)
		}
	}

	// MARK: - Image Picker
	@objc private func importPicture() {
		let picker = UIImagePickerController()
		picker.allowsEditing = true
		picker.delegate = self
		present(picker, animated: UIView.areAnimationsEnabled)
	}

	// MARK: - Sessions
	@objc private func showConnectionPrompt() {
		let alertController = UIAlertController(title: "Connect to others", message: nil, preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: "Host a session", style: .default, handler: startHosting))
		alertController.addAction(UIAlertAction(title: "Join a session", style: .default, handler: joinSession))
		alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		present(alertController, animated: UIView.areAnimationsEnabled)
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
		present(mcBrowser, animated: UIView.areAnimationsEnabled)
	}

	@objc private func showPeersDidTap() {
		guard let mcSession = mcSession else { return }
		let connectedPeers = mcSession.connectedPeers.map { peer -> String in
			peer.displayName
		}

		guard !connectedPeers.isEmpty else {
			let alertController = UIAlertController(title: "No peers", message: "There are no peers connected", preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: "OK", style: .default))
			present(alertController, animated: UIView.areAnimationsEnabled)
			return
		}
		let alertController = UIAlertController(title: "Connected peers", message: connectedPeers.joined(separator: ", "), preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: "OK", style: .default))
		present(alertController, animated: UIView.areAnimationsEnabled)
	}

	private func showHasDisconnectedAlert(peerDisplayName: String) {
		let alertController = UIAlertController(title: "Session ended", message: "\(peerDisplayName) has disconnected", preferredStyle: .alert)
		alertController.addAction(UIAlertAction(title: "OK", style: .default))
		present(alertController, animated: UIView.areAnimationsEnabled)
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

		dismiss(animated: UIView.areAnimationsEnabled)

		images.insert(image, at: 0)
		collectionView.reloadData()

		guard let imageData = image.pngData() else { return }
		send(data: imageData)
	}
}

// MARK: - MCSessionDelegate
extension ViewController: MCSessionDelegate {

	func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
		DispatchQueue.main.async { [weak self] in
			if let image = UIImage(data: data) {
				self?.images.insert(image, at: 0)
				self?.collectionView.reloadData()
			} else {
				let text = String(decoding: data, as: UTF8.self)
				var splittedText = text.split(separator: ";")
				guard splittedText.removeFirst().hasPrefix(Constants.textMessage),
					  let sender = splittedText.first,
					  let message = splittedText.last else { return }
				let alertController = UIAlertController(title: "Message from \(sender)", message: "\(message)", preferredStyle: .alert)
				alertController.addAction(UIAlertAction(title: "OK", style: .default))
				self?.present(alertController, animated: UIView.areAnimationsEnabled)
			}
		}
	}

	func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
		switch state {
		case .connected: print("Connected: \(peerID.displayName)")
		case .connecting: print("Connecting: \(peerID.displayName)")
		case .notConnected: showHasDisconnectedAlert(peerDisplayName: peerID.displayName)
		@unknown default: print("Unknown state: \(peerID.displayName)")
		}

	}

	func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

	func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

	func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCBrowserViewControllerDelegate
extension ViewController: MCBrowserViewControllerDelegate {

	func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
		dismiss(animated: UIView.areAnimationsEnabled)
	}

	func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
		dismiss(animated: UIView.areAnimationsEnabled)
	}
}
