/*

`VideoDetailsViewController` is used to display the info of one or multiple videos.
Currently it's a pretty bare bones form view.

Uses [XLForm](https://github.com/xmartlabs/XLForm) internally.

*/

import Foundation
import XLForm

class VideoDetailsViewController: XLFormViewController {
    
    var video: Video? = nil
    var hasModifications = false
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func initializeForm(video: Video) {
        self.video = video
        self.hasModifications = false
        
        let formTitle = NSLocalizedString("details_form_title", comment: "Title shown in the video details form")
        
        let form = XLFormDescriptor(title: formTitle)
        form.delegate = self
        
        let section = XLFormSectionDescriptor.formSection()
        form.addFormSection(section)
        
            let titleTitle = NSLocalizedString("details_title", comment: "Title field label shown in the video details form")
            let title = XLFormRowDescriptor(tag: "title", rowType: XLFormRowDescriptorTypeText, title: titleTitle)
        
        title.value = self.video!.title
        section.addFormRow(title)

        let readonly = XLFormSectionDescriptor.formSection()
        
        form.addFormSection(readonly)
        
        let creatorTitle = NSLocalizedString("details_creator", comment: "Genre label shown in the video details form")
        let creator = XLFormRowDescriptor(tag: "creator", rowType: XLFormRowDescriptorTypeInfo, title: creatorTitle)
        
        let creatorName = video.author.name
        creator.value = creatorName
        readonly.addFormRow(creator)
        
        let annotationsSection = XLFormSectionDescriptor.formSection()
        annotationsSection.title = "Annotations"
        
        for (index, annotation) in self.video!.annotations.enumerate() {
            let annotationRow = XLFormRowDescriptor(tag: "annotation-\(index)", rowType: XLFormRowDescriptorTypeInfo, title: annotation.author.name)
            
            annotationRow.value = annotation.text
            annotationsSection.addFormRow(annotationRow)
        }
        
        form.addFormSection(annotationsSection)
        
        self.form = form
    }
    
    override func formRowDescriptorValueHasChanged(formRow: XLFormRowDescriptor!, oldValue: AnyObject!, newValue: AnyObject!) {
        guard let tag = formRow.tag else { return }
        
        self.hasModifications = true
        
        switch tag {
            case "title": self.video!.title = newValue as? String ?? ""
            default: break
        }
    }
    
    @IBAction func cancelButtonPressed(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func doneButtonPressed(sender: UIBarButtonItem) {
        if self.hasModifications {
                self.video!.hasLocalModifications = true
                let _ = try? videoRepository.saveVideo(self.video!)
                videoRepository.refreshOnline()
        }

        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

