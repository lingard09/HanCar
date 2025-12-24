//
//  MypageViewController.swift
//  hancar
//
//  Created by kinnwonjin on 12/11/25.
//
//  This view controller manages the user's profile page.
//  It loads user information from Firebase Firestore,
//  displays it in editable fields, and allows the user
//  to update and save their personal and vehicle details.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class MyPageViewController: UIViewController {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet weak var carTypeField: UITextField!
    @IBOutlet weak var carNumberField: UITextField!
    @IBOutlet weak var bankAccountField: UITextField!

    let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        loadUserInfo()
    }

    // MARK: - User Data Loading
    func loadUserInfo() {
        guard let user = Auth.auth().currentUser else { return }

        nameLabel.text = user.displayName ?? "User"

        db.collection("Users").document(user.uid).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                self.phoneField.text = data["phoneNumber"] as? String
                self.carTypeField.text = data["carType"] as? String
                self.carNumberField.text = data["carNumber"] as? String
                self.bankAccountField.text = data["bankAccount"] as? String
            }
        }
    }
    
    // MARK: - Save User Information
    @IBAction func saveTapped(_ sender: UIButton) {
        saveUserInfo()
    }
    
    func saveUserInfo() {
        guard let user = Auth.auth().currentUser else { return }

        let data: [String: Any] = [
            "name": user.displayName ?? "",
            "phoneNumber": phoneField.text ?? "",
            "carType": carTypeField.text ?? "",
            "carNumber": carNumberField.text ?? "",
            "bankAccount": bankAccountField.text ?? ""
        ]

        db.collection("Users")
            .document(user.uid)
            .setData(data, merge: true) { error in

                if error != nil {
                    return
                }

                self.showAlert("Saved")
            }
    }
    
    // MARK: - Alert Handling
    func showAlert(_ message: String) {
        let alert = UIAlertController(
            title: "Alert",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Confirm", style: .default))
        present(alert, animated: true)
    }
}
