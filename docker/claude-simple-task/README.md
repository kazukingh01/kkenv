```bash
bash start.sh --label a # --delete
./resister-instruction.sh myjob --input ./INPUT.md --interval 10 --container claude-code-simple-a
# systemctl list-timers
# sudo systemctl start claude-task-{myjob}.service
# sudo journalctl -u claude-task-{myjob}.timer
# sudo journalctl -u claude-task-{myjob}.service
```
