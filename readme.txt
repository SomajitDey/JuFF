JuFF---Just For Fun (C)2021, Somajit Dey <somajit@users.sourceforge.net>
License: GPL-v3-or-later

"Hello World. I am JuFF :)"

JuFF is a secure messaging & file-sharing app run from an open bash script,
with git as its backend. All messages and files going through JuFF are strongly
encrypted and signed using GNU Privacy Guard. There is no long-term cloud storage
involved, your files and texts live in a server only for a short while (i.e. until 
you download them or till a preset expiry), and that too in a fully encrypted form.

The most exciting thing other than its promise of security is its minimalism. JuFF
comes as a single bash script! You just need to have bash, git & curl installed;
and they usually are in standard Linux systems, including WSL. Just run JuFF.bash 
and you have a totally secure chat+file-sharing app!

So lets see how it all works.

In GitHub, JuFF has a dedicated repo. You get an access token to it from me or others
already using juFF, so that you can use JuFF without having a GitHub account yourself.
This access token is just an entry ticket to JuFF if you will, not your password 
or anything that private. JuFF asks for that token from you on the first run only, and 
never again once your local inbox is setup.

On the first run, JuFF sets up the local inbox on your system, asks for your name & email
, creates a private-public key-pair corresponding to that name & email combination and
gives you your key-ID and a private my_JuFF.key file that holds your private key and SHA-256
passphrase. So, save that file someplace safe as you would need it to gain access to your JuFF 
account on any other machine. Now you just gotta email that key-ID to me. In the background,
JuFF sends your public key to me. I then verify your public key with the keyID you send over 
email, and hence your email verification is done. Following that, the public key is hosted
at Somajit/JuFF-KeyServer at GitHub.

Now you can start sending texts and share files with people whose public keys are already 
hosted. Because of the email verification done before hosting every public key, you can trust
all the keys found at the abovementioned key-server, as I can show you the email that records the 
corresponding KeyID. In future, the registration might become automated, and the KeyID might need
to be sent to a public mailing-list instead.

What happens when you send something?

First it gets signed with your private key and encrypted with the recipient's public key. Hence,
only the recipent will be able to decrypt it and verify your signature using your public key.
Now, it gets sent to an ephemeral file-hosting server such as file.io, oshi.at or 0x0.st
The great thing about these servers is that they are free and file hosting is transient...the
hosted files either expire after a set time or get deleted as soon as you download them.
Following the upload to these servers you get a download link, which JuFF then pushes to git
after signing and encrypting with your private key. So git does not host your encrypted 
correspondence, but rather its download link only. This keeps the repo size managable and makes
your correspondence ultimately untraceable. No one can read the links hosted at git other than 
the desired recipient, as these are encrypted...hence no one else can download something and 
make it get deleted from the server. 

The rest of the story is simple. The recipent pulls from the repo, sees your pushed commit and
extracts the URLs therefrom. JuFF then pulls your public key from the key-server to verify your
signature. Once everthing is found in order, the files are downloaded and decrypted and your 
signatures on them verified. Now your correspondence is saved in your recipients local inbox.

Specifics:

So how secure is git as a backend? Especially when I am giving every participant access to push
to the repo. Anyone can rewrite git history or edit or delete your previous commit(s), right?
True, but here comes GitHub in play. The branch where JuFF pushes is a protected branch that
does not allow force pushes. The branch is also restricted to be a linear branch only and branch
deletion is not allowed. Also the access tokens I am giving out cannot delete the repo.

So the only worry left is what if someone edits or deletes some of your commits and pushes. Well,
git is a VCS folks, keeping track is its job. All JuFF needs to do is to track the git history 
since the last pull it performed on its side. When you run JuFF, it pulls and then tracks every 
single commit since the last time it pulled in reverse chronological order. This is made simpler
because every legitimate commit in JuFF would only add files, and not edit any. This is possible
because every URL filename is timestamped and contain the author's userid, which makes it unique.

Suppose I commited something for you when you were offline. Someone else corrupted it and commited 
again. Your JuFF then first sees the corrupted commit and caches the files unique to that commit.
For this, it uses git restore. It then sees my original commit and again caches the files unique to
my commit. If a file was edited by the attacker, then that file would already have a copy in the 
cache. So, when reading from my commit, JuFF simply replaces the (corrupt) file in the cache with
my original. If on the other hand, the attacker simply deleted a file from my commit, JuFF would
git restore that file from my commit and cache it.

Once the cache is built by running through all the commits individually this way, downloading starts
from the decrypted URLs. Once download is successful, the URL file is removed from the cache. So on 
the next run, if JuFF finds URL files lying in the cache from a previous run, it attempts to download 
them again. Thus, nothing is lost even if you face connection problems.

What if you lose your private key or my_JuFF.key?

You simply tell JuFF to create a new key-pair for you. Then again you email me the key-ID for 
authentication to change your public key on the key-server. Once I update your public key,
all new correspondence use that new public key only. Even if an attacker gets hold of your old
private key, he won't be able to succeed, because the recipient won't be able to match his 
signature using your new public key.

How is this implemented? The public keys are imported just in time and not stored apriori. And here
is another key thing. To verify files unique to a commit, JuFF imports only that version of the 
public key that is present in the last commit in the key-server before the commit-timestamp of the 
said commit in the JuFF repo. For illustration, suppose A commits at time t in the JuFF repo. For all
intents and purposes, A would only use the private key corresponding to last hosted his public key. 
Hence, the correct public key for decrypting A's commit, would be available in the last key-server 
commit before time t! Thats what JuFF imports. What if X now steals the private key of A and commits
to JuFF? If A is prompt in responding to the theft, that commit would happen only after A has published 
a new public key. Hence, all recipients then on would import A's latest public key for the attacker's 
latest commit, and the attacker would be defeated. This way, we don't need revocation certificates 
anymore.

Future work:

1) Users may choose to be anonymous. If a user chooses to be so, his/her JuFF account will be the SHA-256
hash of his/her name#email. So, spammers cannot get his/her validated email id from the JuFF key-server.
Someone who knows his/her name & email both, however, will be able to send him/her messages. But one can
still choose a name and not tell others about it...which then makes his/her JuFF account totally anonymous 
even if others know his/her email id.

2) JuFF can be made to make only signed commits to the JuFF repo. The public keys may already be added to
GitHub so every commit can be verified and displayed as such, for transparency.