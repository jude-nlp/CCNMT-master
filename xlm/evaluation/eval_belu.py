import os
import argparse
import subprocess
from logging import getLogger

BLEU_SCRIPT_PATH = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'multi-bleu.perl')
assert os.path.isfile(BLEU_SCRIPT_PATH)

logger = getLogger()


def get_parser():
    """
    Generate a parameters parser.
    """
    # parse parameters
    parser = argparse.ArgumentParser(description="Language transfer")

    # main parameters
    parser.add_argument("--ref", type=str, default="",
                        help=" ")
    parser.add_argument("--hyp", type=str, default="",
                        help=" ")
    return parser

def eval_moses_bleu(ref, hyp):
    """
    Given a file of hypothesis and reference files,
    evaluate the BLEU score using Moses scripts.
    """
    assert os.path.isfile(hyp)
    assert os.path.isfile(ref) or os.path.isfile(ref + '0')
    assert os.path.isfile(BLEU_SCRIPT_PATH)
    command = BLEU_SCRIPT_PATH + ' %s < %s'
    p = subprocess.Popen(command % (ref, hyp), stdout=subprocess.PIPE, shell=True)
    result = p.communicate()[0].decode("utf-8")
    if result.startswith('BLEU'):
        return float(result[7:result.index(',')])
    else:
        logger.warning('Impossible to parse BLEU score! "%s"' % result)
        return -1

if __name__ == '__main__':
    parser = get_parser()
    params = parser.parse_args()
    BLEU = eval_moses_bleu(params.ref, params.hyp)
    print("ref:{} hyp:{} BLEU: {}".format(params.ref, params.hyp, BLEU))