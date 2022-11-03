# MDM-Prestage-User-Enrollment

<p align="center">
  <img src="https://github.com/TheJumpCloud/MDM-Prestage-User-Enrollment/wiki/images/MDM%20Prestage%20User%20Enrollment%20Banner%20(1).png" width="600">
</p>

The MDM-Prestage-User-Enrollment workflow is designed to minimize work for JumpCloud admins. JumpCloud admins can leverage Apple Automated Enrollment, MDM and JumpCloud to provision devices during device enrollment.

With the aim to Make Work Happen&trade;, the MDM-Prestage-User-Enrollment workflow offers JumpCloud and MDM admins a true zero-touch enrollment experience.

An implementation of the MDM-Prestage-User-Enrollment workflow allows JumpCloud admins to deploy company-owned, MacOS computers to employees around the globe before ever opening the box.

## MacOS Ventura Note/ Future Support

If you have been using this tool in previous versions of macOS, please note that the default version of openssl on mac has changed. The latest version of this script was updated to support Ventura's version of LibreSSL. Please merge your changes from this release into your script if you wish to continue using this script on Ventura systems.

### Future macOS compatibility

With other MDM vendors taking advantage of SSO authentication during enrollment, it's unlikely this script has much of a use case nor will it see much future development. As is the case with JAMF, enabling JumpCloud SSO authentication during enrollment will assign the first user of the system to be the username of JumpCloud user who authenticated during enrollment (assuming your `usernames` match the email convention i.e. username = `username` & email = `username`@domain.com).

This workflow essentially negates the need for the entirety of this script.

A post enrollment script can be used then to:

- [Install the JumpCloud Agent Silently]()
- Search JumpCloud users by username on system
- [Assign the authenticated user to the system](https://docs.jumpcloud.com/api/2.0/index.html#tag/Users/operation/graph_userAssociationsPost)

## How does it work

<p align="center">
  <img src="https://github.com/TheJumpCloud/MDM-Prestage-User-Enrollment/wiki/images/MDM%20Prestage%20User%20Enrollment%20workflow.png" width="600">
</p>

[Apple Automated Deployment](https://support.apple.com/en-us/HT204142) (formally, and more commonly known as DEP) enables admins to build Zero-Touch workflows for their employees. A Mobile Device Management Server [(MDM)](https://support.apple.com/en-us/HT207516) is leveraged to pass configuration settings and an enrollment interface to Apple MacOS computer. Apple and a MDM verify that the MacOS device is under your organizations purview. JumpCloud verifies the identify of a user during enrollment and activates their account on currently enrolled MacOS computer.

During enrollment, existing or pending JumpCloud users are asked to prove their identity. A user who authenticates successfully is provisioned with an account from JumpCloud. Existing users can retain their JumpCloud credentials, new users are prompted to create their password during enrollment

The MDM-Prestage-User-Enrollment workflow is designed to empower admins to automate their enrollment process.

Continue to [the project wiki to start](https://github.com/TheJumpCloud/MDM-Prestage-User-Enrollment/wiki/Getting-Started) building your own Zero-Touch workflow. Check out our [webinar on MDM Prestage User Enrollment](https://jumpcloud.com/resources/using-jumpcloud-for-zero-touch-mdm-enrollment) for more information.
