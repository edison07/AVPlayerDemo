//
//  VideoListTableViewCell.swift
//  GlossikaPlayer
//
//  Created by Edison on 2025/3/12.
//

import UIKit

class VideoListTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subtitleLabel.text = nil
    }
    
    func configure(with video: VideoPlayerModel.Video) {
        titleLabel.text = video.title
        subtitleLabel.text = video.subtitle
    }
}
