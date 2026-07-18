function showBalloons(){

  const colors = [
    "#ff4d4d",
    "#00ff99",
    "#ffd633",
    "#66ccff",
    "#ff66cc",
    "#ffffff"
  ];

  for(let i = 0; i < 25; i++){

    let balloon = document.createElement("div");
    balloon.classList.add("balloon");

    balloon.style.left = Math.random() * 100 + "vw";

    balloon.style.background =
      colors[Math.floor(Math.random() * colors.length)];

    balloon.style.animationDuration =
      (5 + Math.random() * 5) + "s";

    balloon.style.width =
      (40 + Math.random() * 30) + "px";

    balloon.style.height =
      (55 + Math.random() * 40) + "px";

    document.body.appendChild(balloon);

    setTimeout(() => {
      balloon.remove();
    }, 10000);
  }
}