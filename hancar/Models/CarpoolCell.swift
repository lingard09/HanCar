//
//  CarpoolCell.swift
//  hancar
//
//  Created by kinnwonjin on 12/11/25.
//
//  This table view cell displays carpool information
//  and configures its UI based on the user's role
//  (creator, applicant, or available user).
//

import UIKit

class CarpoolCell: UITableViewCell {

    @IBOutlet weak var typeIconLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var routeLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var applyButton: UIButton!

    var onApplyTapped: (() -> Void)?
    
    // MARK: - Cell Configuration
    func configure(with carpool: Carpool, isCreator: Bool, isMyList: Bool = false) {
        typeIconLabel.text = carpool.type == "taxi" ? "🚕" : "🚗"
        timeLabel.text = carpool.time
        routeLabel.text = "\(carpool.departure) → \(carpool.destination)"
        countLabel.text = "\(carpool.currentCount)/\(carpool.maxCount)"
                
        if isCreator {
            applyButton.setTitle("Manage", for: .normal)
            applyButton.backgroundColor = .systemOrange
            applyButton.setTitleColor(.white, for: .normal)
            applyButton.isEnabled = true
            
            contentView.backgroundColor = UIColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1.0)
            return
        }

        if carpool.isApplied {
            contentView.backgroundColor = UIColor(red: 1.0, green: 0.98, blue: 0.85, alpha: 1.0)
            
            applyButton.backgroundColor = .systemGray
            applyButton.setTitleColor(.white, for: .normal)
            
            if isMyList {
                applyButton.isEnabled = true
                applyButton.setTitle("Chat", for: .normal)
            } else {
                applyButton.isEnabled = false
                applyButton.setTitle("Applied", for: .normal)
            }
            return
        }
        
        if carpool.currentCount >= carpool.maxCount {
            applyButton.setTitle("Closed", for: .normal)
            applyButton.backgroundColor = .systemGray
            applyButton.setTitleColor(.white, for: .normal)
            applyButton.isEnabled = false
            
            contentView.backgroundColor = .systemBackground
            return
        }

        applyButton.setTitle("Apply", for: .normal)
        applyButton.setTitleColor(.white, for: .normal)
        applyButton.isEnabled = true
        contentView.backgroundColor = .systemBackground
    }
    
    @IBAction func applyButtonTapped(_ sender: UIButton) {
        onApplyTapped?()
    }
}
