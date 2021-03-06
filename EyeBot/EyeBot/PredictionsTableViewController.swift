//
//  PredictionsTableViewController.swift
//  EyeBot
//
//  Created by Luis Padron on 5/15/17.
//  Copyright © 2017 com.eyebot. All rights reserved.
//

import UIKit
import RealmSwift

class PredictionsTableViewController: UITableViewController {

    lazy var predictions: [StoredPrediction] = {
        let predictions = try! Realm().objects(StoredPrediction.self)
        return Array(predictions).reversed()
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Predictions"
    }


    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return predictions.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "predictionCell", for: indexPath) as! PredictionTableViewCell
        let prediction = predictions[indexPath.row]
        cell.predictionImageView.image = prediction.image
        cell.predictionLabel.text = prediction.label
    
        return cell
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete")
        { (action, indexPath) in
            self.tableView.beginUpdates()
            let predictionToDelete = self.predictions[indexPath.row]
            try! Realm().write {
                try! Realm().delete(predictionToDelete)
            }
            self.predictions.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
            self.tableView.endUpdates()
        }
        
        return [delete]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let prediction = predictions[indexPath.row]
        let cell = self.tableView.cellForRow(at: indexPath) as! PredictionTableViewCell
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyBoard.instantiateViewController(withIdentifier: "predictionDetail") as! PredictionDetailViewController
        controller.imageToPresent = cell.predictionImageView.image
        controller.imageLabel = prediction.label
        
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    // MARK: Actions

    @IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    

}
