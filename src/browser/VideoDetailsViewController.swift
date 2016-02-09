/*

`VideoDetailsViewController` is used to display the info of one or multiple videos.
Currently it's a pretty bare bones form view.

Uses [XLForm](https://github.com/xmartlabs/XLForm) internally.

*/

import Foundation
import XLForm

class VideoDetailsViewController: XLFormViewController {
    
    var videos: [Video] = []
    var hasModifications = false
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func initializeForm(videos: [Video]) {
        self.videos = videos.map { Video(copyFrom: $0) }
        self.hasModifications = false
        
        let formTitle = self.videos.count > 1 ?
            NSLocalizedString("details_form_title_multiple", comment: "Title shown in the video details form with multiple selection") :
            NSLocalizedString("details_form_title", comment: "Title shown in the video details form")
        let form = XLFormDescriptor(title: formTitle)
        form.delegate = self
        
        let section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        if videos.count == 1 {
            let titleTitle = NSLocalizedString("details_title", comment: "Title field label shown in the video details form")
            let title = XLFormRowDescriptor(tag: "title", rowType: XLFormRowDescriptorTypeText, title: titleTitle)
            title.value = videos[0].title
            section.addFormRow(title)
        } else {
            let title = XLFormRowDescriptor(tag: "title", rowType: XLFormRowDescriptorTypeInfo, title: NSLocalizedString("details_title_multiple", comment: "Title field label shown when mutliple videos are selected"))
            title.value = String(videos.count)
            section.addFormRow(title)
        }

        let genreTitle = NSLocalizedString("details_genre", comment: "Genre field label shown in the video details form")
        let genreOptions = Genre.genres.map { XLFormOptionsObject(value: $0.id, displayText: $0.localizedName) }
        let genre = XLFormRowDescriptor(tag: "genre", rowType: XLFormRowDescriptorTypeSelectorPush, title: genreTitle)
        
        let genres = Set(videos.flatMap { video in genreOptions.indexOf { $0.valueData() as? String == video.genre } })
        switch genres.count {
        case 0:
            genre.value = XLFormOptionsObject(value: "unknown", displayText: "")
        case 1:
            genre.value = genreOptions[genres.first!]
        default:
            let genreText = genres.map { genreOptions[$0].displayText() }.joinWithSeparator(", ")
            genre.value = XLFormOptionsObject(value: "multiple", displayText: genreText)
        }
        
        genre.selectorTitle = "Genre"
        genre.selectorOptions = genreOptions

        section.addFormRow(genre)
        
        let readonly = XLFormSectionDescriptor.formSection()
        form.addFormSection(readonly)
        
        let creatorTitle = NSLocalizedString("details_creator", comment: "Genre label shown in the video details form")
        let creator = XLFormRowDescriptor(tag: "creator", rowType: XLFormRowDescriptorTypeInfo, title: creatorTitle)
        
        let creators = Set(videos.map { $0.author.name })
        
        creator.value = creators.joinWithSeparator(", ")
        readonly.addFormRow(creator)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(formRow: XLFormRowDescriptor!, oldValue: AnyObject!, newValue: AnyObject!) {
        guard let tag = formRow.tag else { return }
        
        self.hasModifications = true
        
        for video in self.videos {
            switch tag {
            case "title": video.title = newValue as? String ?? ""
            case "genre": video.genre = (newValue as! XLFormOptionsObject).valueData() as! String
            default: break
            }
        }
    }
    
    @IBAction func cancelButtonPressed(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func doneButtonPressed(sender: UIBarButtonItem) {
        if self.hasModifications {
            for video in self.videos {
                video.hasLocalModifications = true
                try? videoRepository.saveVideo(video)
                videoRepository.refreshOnline()
            }
        }

        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

