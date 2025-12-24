//
//  ConfirmViewController.swift
//  hancar
//
//  Created by kinnwonjin on 12/13/25.
//
//  This view controller displays carpool information
//  and allows the user to confirm or cancel joining a carpool.
//  When confirmed, it updates the carpool participant count
//  and stores the applied carpool in Firestore.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class ConfirmViewController: UIViewController {

    var carpool: Carpool?

    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var routeLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }


    func updateUI() {
        guard let c = carpool else { return }

        typeLabel.text = c.type == "taxi" ? "🚕" : "🚗"
        timeLabel.text = c.time
        routeLabel.text = "\(c.departure) → \(c.destination)"
        countLabel.text = "\(c.currentCount) / \(c.maxCount)"
    }

    @IBAction func cancelTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }
    // Update carpool current count
    @IBAction func confirmTapped(_ sender: UIButton) {
        guard
            let c = carpool,
            let uid = Auth.auth().currentUser?.uid
        else { return }

        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Update carpool current count
        let carpoolRef = db.collection("carpools").document(c.id)
        batch.updateData([
            "currentCount": FieldValue.increment(Int64(1))
        ], forDocument: carpoolRef)
        
        // Update user's applied carpools
        let userRef = db.collection("Users").document(uid)
        batch.setData([
            "appliedCarpools": FieldValue.arrayUnion([c.id])
        ], forDocument: userRef, merge: true)

        batch.commit { [weak self] error in
            if let error {
                self?.showAlert(title: "Apply Failed", message: error.localizedDescription)
                return
            }

            self?.showAlert(
                title: "Apply Success",
                message: "You can check it in My Carpool List"
            )
        }
    }

    // MARK: - Alert
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(
            title: "Confirm",
            style: .default
        ) { [weak self] _ in
            self?.dismiss(animated: true)
        })

        present(alert, animated: true)
    }

}
