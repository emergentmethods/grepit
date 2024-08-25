# grepit
The secure way to to never remember terminal commands

![image](https://github.com/user-attachments/assets/149bf34a-0c0d-4dc4-8192-25e9c4afe5f1)

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


![image](https://github.com/user-attachments/assets/b9417224-f3db-4f17-9ed8-eb58678e3196)

![image](https://github.com/user-attachments/assets/5770cd03-c675-4d2d-9c2a-173ae80e38c5)

