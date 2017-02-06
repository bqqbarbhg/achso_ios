/*

`VideoDetailsViewController` is used to display the info of one or multiple videos.
Currently it's a pretty bare bones form view.

Uses [XLForm](https://github.com/xmartlabs/XLForm) internally.

*/

import Foundation
import XLForm

class VideoDetailsViewController: XLFormViewController {
    
    var video: Video? = nil
    var startTime : Double = 0.0
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
        
        let generalSectionTitle = NSLocalizedString("general_settings", comment: "Heading for the miscalleneous options in Details view")
        let generalSection = XLFormSectionDescriptor.formSectionWithTitle(generalSectionTitle)
        
        let titleTitle = NSLocalizedString("details_title", comment: "Title field label shown in the video details form")
        let title = XLFormRowDescriptor(tag: "title", rowType: XLFormRowDescriptorTypeText, title: titleTitle)
    
        title.value = self.video!.title
        
        let creatorTitle = NSLocalizedString("details_creator", comment: "Genre label shown in the video details form")
        let creatorRow = XLFormRowDescriptor(tag: "creator", rowType: XLFormRowDescriptorTypeInfo, title: creatorTitle)
        
        let creatorName = video.author.name
        creatorRow.value = creatorName

        let isPublicTitle = NSLocalizedString("is_video_searchable", comment: "Is  searchable?")
        
        let isPublicRow = XLFormRowDescriptor(tag: "isPublic", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: isPublicTitle)
        
        isPublicRow.value = video.isPublic
        generalSection.addFormRow(title)
        generalSection.addFormRow(creatorRow)
        generalSection.addFormRow(isPublicRow)
        
        form.addFormSection(generalSection)
        
        let annotationsSection = XLFormSectionDescriptor.formSection()
        let annotationsSectionTitle = NSLocalizedString("list_of_annotations", comment: "List of annotations")
        annotationsSection.title = annotationsSectionTitle
        
        for (index, annotation) in self.video!.annotations.enumerate() {
            let annotationRow = XLFormRowDescriptor(tag: "annotation-\(index)", rowType: XLFormRowDescriptorTypeInfo, title: annotation.author.name)
            
            annotationRow.value = annotation.text
            annotationsSection.addFormRow(annotationRow)
        }
        
        form.addFormSection(annotationsSection)
        
        let groupsSection = XLFormSectionDescriptor.formSection()
        let groupsList = AppDelegate.instance.loadGroups()
        
        for group in (groupsList?.groups)! {
            let isShared = group.videos.contains(video.id)
            
            let groupRow = XLFormRowDescriptor(tag: "group-\(group.id)", rowType: XLFormRowDescriptorTypeBooleanSwitch, title: group.name)
            
            groupRow.value = isShared
            groupsSection.addFormRow(groupRow)
        }
        
        let groupsSectionTitle = NSLocalizedString("share_to_groups", comment: "Share with groups")
        groupsSection.title = groupsSectionTitle
        
        form.addFormSection(groupsSection)
        
        self.form = form
    }
    
    override func didSelectFormRow(formRow: XLFormRowDescriptor!) {
        guard let tag = formRow.tag else { return }
        
        if tag.hasPrefix("annotation") {
            let index = self.parseIntFromTagSeparator(tag)
            self.showVideoAtTime((self.video?.annotations[index].time)!)
        }
    }
    
    func parseIntFromTagSeparator(tag: String) -> Int {
        if let index = Int(tag.componentsSeparatedByString("-")[1]) {
            return index
        }
        
        return -1
    }
    
    
    func setShareStatus(groupId: Int, isShared: Bool) {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        if (isShared) {
            appDelegate.shareVideoToGroup(self.video!, groupId: groupId)
        } else {
            appDelegate.unshareVideoToGroup(self.video!, groupId: groupId)
        }
    }
    
    func setPublicity(isPublic: Bool) {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        if isPublic {
            appDelegate.makeVideoPublic(self.video!)
        } else {
            appDelegate.makeVideoPrivate(self.video!)
        }
    }
    
    func handleAnnotationItemTap(index: Int) {
        let annotation : Annotation = self.video!.annotations[index]
        self.showVideoAtTime(annotation.time)
    }
    
    override func formRowDescriptorValueHasChanged(formRow: XLFormRowDescriptor!, oldValue: AnyObject!, newValue: AnyObject!) {
        guard let tag = formRow.tag else { return }
        
        if tag.hasPrefix("group"), let asBool = newValue as? Bool {
            let id = self.parseIntFromTagSeparator(tag)
            setShareStatus(id, isShared: asBool)
        }
        
        switch tag {
            case "title":
                self.video!.title = newValue as? String ?? ""
                break
            case "isPublic":
                self.setPublicity((newValue as? Bool)!)
                break
            default: break
        }
        
        self.hasModifications = true
    }
    
    func showVideoAtTime(time : Double) {
        self.startTime = time
        self.performSegueWithIdentifier("showPlayerFromTime", sender: self)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        func handleShowPlayer(viewController: UIViewController) {
            guard let navigationController = viewController as? UINavigationController else {
                return
            }
            
            guard let playerViewController = navigationController.topViewController as? PlayerViewController else {
                return
            }

            if let video = self.video {
                do {
                    try playerViewController.setVideo(video)
                    playerViewController.setStartTime(self.startTime)
                    videoRepository.refreshVideo(video, isView: true, callback: playerViewController.videoDidUpdate)
                } catch {
                    // TODO: Cancel segue
                }
            }
        }
        
        let handlers = [
            "showPlayerFromTime": handleShowPlayer,
        ]
        
        guard let identifier = segue.identifier else { return }
        guard let handler = handlers[identifier] else { return }
        
        handler(segue.destinationViewController)
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

