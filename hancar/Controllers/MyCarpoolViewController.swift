//
//  MyCarpoolViewController.swift
//  hancar
//
//  Created by kinnwonjin on 12/14/25.
//
//  This view controller displays the list of carpools
//  that the current user has either created or applied to.
//  Carpools are grouped by date, and users can navigate to
//  chat rooms, delete carpools they created, or cancel
//  applications they have made.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class MyCarpoolViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private let db = Firestore.firestore()
    
    private var allMyCarpools: [Carpool] = []
    private var sectionDates: [Date] = []
    private var carpoolsByDate: [Date: [Carpool]] = [:]
    
    private var selectedCarpool: Carpool?

    let sectionHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "MM/dd (E)"
        return f
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "My Carpool List"
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchMyData()
    }
}

// MARK: - Table View Setup & Data Source
extension MyCarpoolViewController: UITableViewDataSource, UITableViewDelegate {

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionDates.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < sectionDates.count else { return nil }
        return sectionHeaderFormatter.string(from: sectionDates[section])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < sectionDates.count else { return 0 }
        let date = sectionDates[section]
        return carpoolsByDate[date]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: "CarpoolCell",
            for: indexPath
        ) as! CarpoolCell

        guard indexPath.section < sectionDates.count,
              let date = sectionDates.first(where: { $0 == sectionDates[indexPath.section] }),
              let carpools = carpoolsByDate[date] else {
            return UITableViewCell()
        }
        
        let carpool = carpools[indexPath.row]
        let currentUserUid = Auth.auth().currentUser?.uid ?? ""
        let isCreator = (carpool.creatorUid == currentUserUid)
        
        cell.configure(with: carpool, isCreator: isCreator, isMyList: true)
        
        cell.applyButton.setTitle("Chat", for: .normal)
        
        cell.onApplyTapped = nil
        cell.onApplyTapped = { [weak self] in
            guard let self = self else { return }
            self.selectedCarpool = carpool
            self.performSegue(withIdentifier: "ShowChatRoom", sender: nil)
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        guard indexPath.section < sectionDates.count,
              let date = sectionDates.first(where: { $0 == sectionDates[indexPath.section] }),
              let carpools = carpoolsByDate[date] else {
            return nil
        }
        
        let carpool = carpools[indexPath.row]
        let currentUserUid = Auth.auth().currentUser?.uid ?? ""
        let isCreator = (carpool.creatorUid == currentUserUid)
        
        if isCreator {
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completionHandler) in
                self?.confirmDelete(carpool)
                completionHandler(true)
            }
            deleteAction.backgroundColor = .systemRed
            return UISwipeActionsConfiguration(actions: [deleteAction])
            
        } else {
            let cancelAction = UIContextualAction(style: .destructive, title: "Cancel") { [weak self] (_, _, completionHandler) in
                self?.showCancelConfirmation(for: carpool)
                completionHandler(true)
            }
            cancelAction.backgroundColor = .systemOrange
            return UISwipeActionsConfiguration(actions: [cancelAction])
        }
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? ChatRoomViewController,
                  segue.identifier == "ShowChatRoom" {
            vc.carpool = selectedCarpool
        }
    }
}

// MARK: - Firestore Data Fetching
extension MyCarpoolViewController {

    private func fetchMyData() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let dispatchGroup = DispatchGroup()
        var createdList: [Carpool] = []
        var appliedList: [Carpool] = []
        
        dispatchGroup.enter()
        db.collection("carpools")
            .whereField("creatorUid", isEqualTo: uid)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents {
                    createdList = documents.compactMap { Carpool(document: $0, appliedCarpoolIDs: []) }
                }
                dispatchGroup.leave()
            }
        
        dispatchGroup.enter()
        db.collection("Users").document(uid).getDocument { snapshot, error in
            guard let data = snapshot?.data(),
                  let ids = data["appliedCarpools"] as? [String], !ids.isEmpty else {
                dispatchGroup.leave()
                return
            }
            
            let innerGroup = DispatchGroup()
            for id in ids {
                innerGroup.enter()
                self.db.collection("carpools").document(id).getDocument { doc, _ in
                    if let doc = doc, doc.exists,
                       let carpool = Carpool(document: doc, appliedCarpoolIDs: Set(ids)) {
                        appliedList.append(carpool)
                    }
                    innerGroup.leave()
                }
            }
            
            innerGroup.notify(queue: .main) {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            let combined = createdList + appliedList
            
            var uniqueDict: [String: Carpool] = [:]
            for cp in combined {
                uniqueDict[cp.id] = cp
            }
            
            self.allMyCarpools = Array(uniqueDict.values)
            self.rebuildSections()
            self.tableView.reloadData()
        }
    }
    
    private func rebuildSections() {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy/MM/dd"

        carpoolsByDate = Dictionary(grouping: allMyCarpools) { carpool in
            let full = "\(carpool.year)/\(carpool.date)"
            let parsed = formatter.date(from: full) ?? Date()
            return calendar.startOfDay(for: parsed)
        }

        sectionDates = carpoolsByDate.keys.sorted()

        for date in sectionDates {
            carpoolsByDate[date]?.sort { $0.time < $1.time }
        }
    }
}

// MARK: - Action Logic (Delete & Cancel)
extension MyCarpoolViewController {

    private func confirmDelete(_ carpool: Carpool) {
        let alert = UIAlertController(title: "Delete Carpool", message: "This cannot be undone.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteCarpool(carpool)
        })
        present(alert, animated: true)
    }
    
    private func deleteCarpool(_ carpool: Carpool) {
        db.collection("carpools").document(carpool.id).delete { [weak self] error in
            if let error = error {
                return
            }
            self?.fetchMyData()
        }
    }

    private func showCancelConfirmation(for carpool: Carpool) {
        let alert = UIAlertController(
            title: "Cancel Application",
            message: "Are you sure you want to cancel?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive) { [weak self] _ in
            self?.cancelCarpool(carpool)
        })
        present(alert, animated: true)
    }
    
    private func cancelCarpool(_ carpool: Carpool) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        let carpoolRef = db.collection("carpools").document(carpool.id)
        let userRef = db.collection("Users").document(uid)
        
        batch.updateData(["currentCount": FieldValue.increment(Int64(-1))], forDocument: carpoolRef)
        batch.updateData(["appliedCarpools": FieldValue.arrayRemove([carpool.id])], forDocument: userRef)
        
        batch.commit { [weak self] error in
            if let error = error {
                return
            }
            self?.fetchMyData()
            
            DispatchQueue.main.async {
                let success = UIAlertController(title: "Canceled", message: "Application canceled.", preferredStyle: .alert)
                success.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(success, animated: true)
            }
        }
    }
}
