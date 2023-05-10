

import UIKit

public class GlassesCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var backView: UIView!
    @IBOutlet weak var glassesImageView: UIImageView!
    
    private let cornerRadius: CGFloat = 10
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backView.layer.cornerRadius = cornerRadius
    }
    
    func setup(with image: UIImage) {
        glassesImageView.image = image
    }
}
