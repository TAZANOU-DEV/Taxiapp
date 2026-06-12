const bcrypt = require('bcrypt');

async function generateHash() {
    const password = 'nlstazan@62005';
    const hash = await bcrypt.hash(password, 10);

    console.log(hash);
}

generateHash();