//
//  CreateViewController.swift
//  hancar
//
//  Created by kinnwonjin on 12/11/25.
//
//  This view controller is responsible for creating and editing carpools.
//  It provides a shared UI for both modes and stores carpool data
//  in Firestore, including date, time, capacity, and notice.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class CreateCarpoolViewController: UIViewController {

    @IBOutlet weak var typeSegmented: UISegmentedControl!
    @IBOutlet weak var departureField: UITextField!
    @IBOutlet weak var destinationField: UITextField!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var timePicker: UIDatePicker!
    @IBOutlet weak var maxCountStepper: UIStepper!
    @IBOutlet weak var maxCountLabel: UILabel!
    @IBOutlet weak var noticeField: UITextView!
    
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var actionButton: UIButton?
    
    let db = Firestore.firestore()
    
    var carpoolToEdit: Carpool?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCommonUI()
        
        if let carpool = carpoolToEdit {
            setupEditMode(with: carpool)
        } else {
            setupCreateMode()
        }
    }
    
    func setupCommonUI() {
        maxCountLabel.text = "\(Int(maxCountStepper.value))"
        noticeField.layer.borderColor = UIColor.systemGray4.cgColor
        noticeField.layer.borderWidth = 1
        noticeField.layer.cornerRadius = 8
    }
    
    func setupCreateMode() {
        titleLabel?.text = "Create Carpool"
        actionButton?.setTitle("Create", for: .normal)
    }
    
    func setupEditMode(with carpool: Carpool) {
        titleLabel?.text = "Edit Carpool"
        actionButton?.setTitle("Edit", for: .normal)
                
        departureField.text = carpool.departure
        destinationField.text = carpool.destination
        noticeField.text = carpool.notice
        
        typeSegmented.selectedSegmentIndex = (carpool.type == "taxi") ? 1 : 0
        
        maxCountStepper.value = Double(carpool.maxCount)
        maxCountLabel.text = "\(carpool.maxCount)"
        
        if let dateObj = stringToDate(dateString: carpool.date) {
            datePicker.date = dateObj
        }
        if let timeObj = stringToTime(timeString: carpool.time) {
            timePicker.date = timeObj
        }
    }

    @IBAction func maxCountChanged(_ sender: UIStepper) {
        maxCountLabel.text = "\(Int(sender.value))"
    }
    
    @IBAction func createCarpoolTapped(_ sender: UIButton) {
        if carpoolToEdit != nil {
            editCarpool()
        } else {
            createCarpool()
        }
    }
    
    // MARK: - Firestore (Create / Edit)
    func createCarpool() {
        guard let user = Auth.auth().currentUser else { return }
        guard
            let departure = departureField.text, !departure.isEmpty,
            let destination = destinationField.text, !destination.isEmpty,
            let notice = noticeField.text
        else {
            showAlert("Fill all field.")
            return
        }

        let type = typeSegmented.selectedSegmentIndex == 0 ? "carpool" : "taxi"
        let calendar = Calendar.current
        let year = calendar.component(.year, from: datePicker.date)

        let data: [String: Any] = [
            "type": type,
            "departure": departure,
            "destination": destination,
            "year": year,
            "date": formattedDateString(from: datePicker.date),
            "time": formattedTimeString(from: timePicker.date),
            "currentCount": 1,
            "maxCount": Int(maxCountStepper.value),
            "notice": notice,
            "cost": "",
            "creatorUid": user.uid,
            "createdAt": Timestamp()
        ]

        db.collection("carpools").addDocument(data: data) { error in
            if error != nil {
                return
            }

            DispatchQueue.main.async {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func editCarpool() {
        guard let carpool = carpoolToEdit else { return }
        
        guard
            let departure = departureField.text, !departure.isEmpty,
            let destination = destinationField.text, !destination.isEmpty,
            let notice = noticeField.text
        else {
            showAlert("Fill all field.")
            return
        }
        
        let type = typeSegmented.selectedSegmentIndex == 0 ? "carpool" : "taxi"
        let calendar = Calendar.current
        let year = calendar.component(.year, from: datePicker.date)
        
        let updateData: [String: Any] = [
            "type": type,
            "departure": departure,
            "destination": destination,
            "year": year,
            "date": formattedDateString(from: datePicker.date),
            "time": formattedTimeString(from: timePicker.date),
            "maxCount": Int(maxCountStepper.value),
            "notice": notice,
            "updatedAt": Timestamp()
        ]
        
        db.collection("carpools").document(carpool.id).updateData(updateData) { [weak self] error in
            if error != nil {
                return
            }
            DispatchQueue.main.async {
                self?.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    // MARK: - Date & Time Formatting
    func formattedTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"

        return formatter.string(from: date)
    }
    
    func formattedDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "MM/dd"

        return formatter.string(from: date)
    }

    func stringToDate(dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let currentYear = Calendar.current.component(.year, from: Date())
        return formatter.date(from: "\(currentYear)/\(dateString)")
    }

    func stringToTime(timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString)
    }
    
    // MARK: - Alert
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
