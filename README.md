![image](https://github.com/user-attachments/assets/6b39d6ca-1762-449c-8e91-26ea69613309)

# grepit

The secure way to to never remember terminal commands.

Wanna know how to use it?

```bash
sudo apt install fzf
vim ~/.bashrc
```

Copy the following text into the bottom of the bashrc file:

```bash
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

```bash
source ~/.bashrc
```

Use it with

```bash
grepit <search term>
```


![image](https://github.com/user-attachments/assets/b9417224-f3db-4f17-9ed8-eb58678e3196)

![image](https://github.com/user-attachments/assets/5770cd03-c675-4d2d-9c2a-173ae80e38c5)

