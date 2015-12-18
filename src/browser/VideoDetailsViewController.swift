import Foundation
import XLForm

class VideoDetailsViewController: XLFormViewController {
    
    var video: Video?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func initializeForm(video: Video) {
        self.video = Video(copyFrom: video)
        
        let formTitle = NSLocalizedString("details_form_title", comment: "Title shown in the video details form")
        let form = XLFormDescriptor(title: formTitle)
        form.delegate = self
        
        let section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
        let titleTitle = NSLocalizedString("details_title", comment: "Title field label shown in the video details form")
        let title = XLFormRowDescriptor(tag: "title", rowType: XLFormRowDescriptorTypeText, title: titleTitle)
        title.value = video.title
        section.addFormRow(title)

        let genreTitle = NSLocalizedString("details_genre", comment: "Genre field label shown in the video details form")
        let genreOptions = Genre.genres.map { XLFormOptionsObject(value: $0.id, displayText: $0.localizedName) }
        let index = genreOptions.indexOf { $0.valueData() as? String == video.genre }
        
        let genre = XLFormRowDescriptor(tag: "genre", rowType: XLFormRowDescriptorTypeSelectorPush, title: genreTitle)
        genre.value = genreOptions[index ?? 0]
        genre.selectorTitle = "Genre"
        genre.selectorOptions = genreOptions

        section.addFormRow(genre)
        
        let readonly = XLFormSectionDescriptor.formSection()
        form.addFormSection(readonly)
        
        let creatorTitle = NSLocalizedString("details_creator", comment: "Genre label shown in the video details form")
        let creator = XLFormRowDescriptor(tag: "creator", rowType: XLFormRowDescriptorTypeInfo, title: creatorTitle)
        creator.value = video.author.name
        readonly.addFormRow(creator)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(formRow: XLFormRowDescriptor!, oldValue: AnyObject!, newValue: AnyObject!) {
        guard let video = self.video, tag = formRow.tag else { return }
        
        switch tag {
        case "title": video.title = newValue as? String ?? ""
        case "genre": video.genre = (newValue as! XLFormOptionsObject).valueData() as! String
        default: break
        }
    }
    
    @IBAction func cancelButtonPressed(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func doneButtonPressed(sender: UIBarButtonItem) {
        if let video = self.video {
            video.hasLocalModifications = true
            try? videoRepository.saveVideo(video)
            videoRepository.refreshOnline()
        }

        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

