import './styles.scss';
import './index.html';
import { Elm } from './elm/Main.elm';

const SCOREBOARD_KEY = 'minesweeper-scoreboard';

const app = Elm.Main.init();

function getScores() {
    return JSON.parse(localStorage.getItem(SCOREBOARD_KEY) ?? '[]');
}

function setScores(scoreboard) {
    localStorage.setItem(SCOREBOARD_KEY, JSON.stringify(scoreboard));
}

function scoresUpdated() {
    const scoreboard = getScores();
    app.ports.scoreboardUpdated.send(scoreboard);
}

app.ports.saveScore.subscribe(time => {
    const name = prompt('You win! Name:') ?? '';
    const scoreboard = getScores();
    scoreboard.push({name, time});
    scoreboard.sort((a, b) => a.time - b.time);
    setScores(scoreboard);

    scoresUpdated();
});

window.addEventListener('storage', e => {
    if (e.storageArea === localStorage && e.key === SCOREBOARD_KEY) {
        scoresUpdated();
    }
});

scoresUpdated();
