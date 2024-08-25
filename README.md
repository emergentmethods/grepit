# grepit
The secure way to to never remember terminal commands


Wanna know how to us it?

```
sudo apt install fzf
vim ~/.bashrc
```

Copy the following text into the bottom of the bashrc file:

```
grepit() {
 local search_term="$1"
 local cmd

 if [ -n "$search_term" ]; then
 cmd=$(history | tac | grep "$search_term" | fzf --height=100% --layout=reverse --border --prompt="Select command to run: " --no-preview | sed 's/^[ ]*[0-9]*[ ]*//')
 else
 cmd=$(history | tac | fzf --height=100% --layout=reverse --border --prompt="Select command to run: " --no-preview | sed 's/^[ ]*[0-9]*[ ]*//')
 fi

 if [ -n "$cmd" ]; then
 echo "Running: $cmd"
 eval "$cmd"
 else
 echo "No command selected."
 fi
}
```

And then 

```
source ~/.bashrc
```

Use it with

```
grepit <search term>
```

![image](https://github.com/user-attachments/assets/149bf34a-0c0d-4dc4-8192-25e9c4afe5f1)
