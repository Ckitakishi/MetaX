//
//  LocationSearchViewController.swift
//  MetaX
//
//  Created by Ckitakishi on 2018/04/11.
//  Copyright © 2018年 Yuhan Chen. All rights reserved.
//

import UIKit
import MapKit
import SVProgressHUD

protocol LocationSearchDelegate {
    func didSelect(_ model: LocationModel)
}

class LocationSearchViewController: UIViewController  {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var listTableView: UITableView!
    
    var resultDataSource: [MKLocalSearchCompletion] = []
    var selectedModel: MKLocalSearchCompletion!
    
    var delegate: LocationSearchDelegate!
    let locationManager = CLLocationManager()
    let completer = MKLocalSearchCompleter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        locationManager.delegate = self
        listTableView.delegate = self
        listTableView.dataSource = self
        
        listTableView.keyboardDismissMode = .onDrag
        
        completer.delegate = self
    }
    
    // MARK: Action
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func neighborSearch(_ sender: UIBarButtonItem) {

        let status = CLLocationManager.authorizationStatus()
        if status == CLAuthorizationStatus.notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()
    }
}

// MARK: CLLocationManager Delegate
extension LocationSearchViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {

    }
}

// MARK: UISearchBar Delegate
extension LocationSearchViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.count > 0 {
              completer.queryFragment = searchText
        } else {
            resultDataSource.removeAll()
            listTableView.reloadData()
        }
    }
}

// MARK: MKLocalSearchCompleter Delegate
extension LocationSearchViewController: MKLocalSearchCompleterDelegate {
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.resultDataSource = completer.results
        listTableView.reloadData()
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // handle error
        SVProgressHUD.showCustomErrorHUD(with: error.localizedDescription)
    }
}

// MARK: ListTableView Datasource
extension LocationSearchViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultDataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: LocationTableViewCell.self), for: indexPath) as! LocationTableViewCell
        cell.cellDataSource = resultDataSource[indexPath.row]
        return cell
    }
}

// MARK: ListTableView Delegate
extension LocationSearchViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dismiss(animated: true, completion: nil)
        
        selectedModel = resultDataSource[indexPath.row]
        var completionModel = LocationModel(with: selectedModel)
        
        let searchRequest = MKLocalSearch.Request(completion: selectedModel)
        let search = MKLocalSearch(request: searchRequest)
        search.start { (response, error) in
            if let coordinate = response?.mapItems[0].placemark.coordinate {
                completionModel.coordinate = coordinate
            }
            self.delegate.didSelect(completionModel)
        }
    }
}

