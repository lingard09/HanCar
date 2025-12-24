//
//  MainViewController.swift
//  hancar
//
//  Created by kinnwonjin on 12/11/25.
//
//  This view controller displays the main carpool list.
//  It loads carpools from Firestore in real time, groups them by date,
//  and allows users to apply for, edit, or delete carpools.
//  It also manages user-specific states such as applied carpools
//  and provides pull-to-refresh and loading indicators.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class MainViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var welcomeLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBAction func refreshTapped(_ sender:  UIButton) {
        sender.isEnabled = false
        showLoading()
        
        let startTime = Date()
        
        fetchAppliedCarpoolIDs { [weak self] in
            guard let self = self else { return }
            
            self.rebuildSections()
            
            let elapsed = Date().timeIntervalSince(startTime)
            let delay = max(0, 1.0 - elapsed)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.tableView.reloadData()
                self.hideLoading()
                sender.isEnabled = true
            }
        }
    }
    
    let db = Firestore.firestore()
    private var carpoolListener: ListenerRegistration?
    
    private var carpools: [Carpool] = []
    private var appliedCarpoolIDs: Set<String> = []
    
    private var sectionDates: [Date] = []
    private var carpoolsByDate: [Date: [Carpool]] = [:]
    
    private let refreshControl = UIRefreshControl()
    
    private var loadingIndicator: UIActivityIndicatorView!
    private var loadingBackgroundView: UIView!
    
    let sectionHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MM/dd (E)"
        return f
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setWelcomeMessage()
        setupTableView()
        setupLoadingIndicator()
        
        fetchAppliedCarpoolIDs {
            self.listenCarpools()
        }
    }
    
    deinit {
        carpoolListener?.remove()
    }
}

// MARK: - UI Setup
extension MainViewController {

    func setWelcomeMessage() {
        guard let user = Auth.auth().currentUser else {
            welcomeLabel.text = "Hello!"
            return
        }
        let name = user.displayName ?? "User"
        welcomeLabel.text = "Welcome, \(name)"
    }

    func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    @objc private func handleRefresh() {
        fetchAppliedCarpoolIDs { [weak self] in
            DispatchQueue.main.async {
                self?.refreshControl.endRefreshing()
            }
        }
    }
}

// MARK: - UITableView DataSource & Delegate
extension MainViewController {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sectionDates.count
    }

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        guard let date = dateForSectionIndex(section) else { return 0 }
        return carpoolsByDate[date]?.count ?? 0
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: "CarpoolCell",
            for: indexPath
        ) as! CarpoolCell

        guard let date = dateForSectionIndex(indexPath.section),
              let sectionCarpools = carpoolsByDate[date] else {
            return UITableViewCell()
        }
        
        let carpool = sectionCarpools[indexPath.row]
        let currentUserSum = Auth.auth().currentUser?.uid ?? ""
        let isCreator = (carpool.creatorUid == currentUserSum)
        
        cell.configure(with: carpool, isCreator: isCreator, isMyList: false)
        
        cell.onApplyTapped = nil
        cell.onApplyTapped = { [weak self] in
            guard let self = self else { return }
            
            if isCreator {
                self.showCreatorOptions(for: carpool)
            } else {
                self.showConfirm(carpool: carpool)
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        guard let date = dateForSectionIndex(section) else { return nil }
        return sectionHeaderFormatter.string(from: date)
    }
}

// MARK: - Firestore Data Handling
extension MainViewController {

    func fetchAppliedCarpoolIDs(completion: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion()
            return
        }

        db.collection("Users")
            .document(uid)
            .getDocument { [weak self] snapshot, _ in
                let ids = snapshot?.data()?["appliedCarpools"] as? [String] ?? []
                self?.appliedCarpoolIDs = Set(ids)
                completion()
            }
    }

    func listenCarpools() {
        carpoolListener?.remove()

        carpoolListener = db.collection("carpools")
            .order(by: "date")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self,
                      let documents = snapshot?.documents else { return }

                self.carpools = documents.compactMap {
                    Carpool(document: $0, appliedCarpoolIDs: self.appliedCarpoolIDs)
                }

                self.rebuildSections()

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
    }
}

// MARK: - Section Management
extension MainViewController {

    private func rebuildSections() {
        let calendar = Calendar.current

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy/MM/dd"

        carpoolsByDate = Dictionary(grouping: carpools) { carpool in
            let full = "\(carpool.year)/\(carpool.date)"
            let parsed = formatter.date(from: full) ?? Date()
            return calendar.startOfDay(for: parsed)
        }

        sectionDates = carpoolsByDate.keys.sorted()

        for date in sectionDates {
            carpoolsByDate[date]?.sort { $0.time < $1.time }
        }
    }

    private func dateForSectionIndex(_ section: Int) -> Date? {
        guard section >= 0, section < sectionDates.count else { return nil }
        return sectionDates[section]
    }
}

// MARK: - Navigation
extension MainViewController {

    func showConfirm(carpool: Carpool) {
        let vc = storyboard?.instantiateViewController(
            withIdentifier: "ConfirmViewController"
        ) as! ConfirmViewController

        vc.carpool = carpool
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true)
    }
    
    func moveToEditScreen(data: Carpool) {
        guard let createVC = self.storyboard?.instantiateViewController(withIdentifier: "CreateCarpoolViewController") as? CreateCarpoolViewController else {
            return
        }
        
        createVC.carpoolToEdit = data
        createVC.modalPresentationStyle = .automatic
        self.present(createVC, animated: true)
    }
}

// MARK: - Creator Actions (Edit / Delete)
extension MainViewController {
    
    func showCreatorOptions(for carpool: Carpool) {
        let alert = UIAlertController(
            title: "Manage Carpool",
            message: "What would you like to do?",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.moveToEditScreen(data: carpool)
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.confirmDelete(carpool)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    func confirmDelete(_ carpool: Carpool) {
        let alert = UIAlertController(
            title: "Delete Carpool",
            message: "Are you sure? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteCarpool(carpool)
        })
        
        present(alert, animated: true)
    }
    
    func deleteCarpool(_ carpool: Carpool) {
        db.collection("carpools").document(carpool.id).delete { [weak self] error in
            if let error = error {
                return
            }
            
            DispatchQueue.main.async {
                let successAlert = UIAlertController(title: "Deleted", message: "Your carpool has been deleted.", preferredStyle: .alert)
                successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(successAlert, animated: true)
            }
        }
    }
}

// MARK: - Loading Indicator
extension MainViewController {
    
    private func setupLoadingIndicator() {
        loadingBackgroundView = UIView(frame: view.bounds)
        loadingBackgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        loadingBackgroundView.isHidden = true
        loadingBackgroundView.autoresizingMask = [. flexibleWidth, .flexibleHeight]
        
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .white
        loadingIndicator.center = view.center
        loadingIndicator.hidesWhenStopped = true
        
        view.addSubview(loadingBackgroundView)
        view.addSubview(loadingIndicator)
    }
    
    private func showLoading() {
        loadingBackgroundView.isHidden = false
        loadingIndicator.startAnimating()
    }
    
    private func hideLoading() {
        loadingBackgroundView.isHidden = true
        loadingIndicator.stopAnimating()
    }
}
